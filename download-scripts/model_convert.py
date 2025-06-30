import sys
import os
import shutil
import subprocess
import json
import torch
import timm
from openvino.tools.mo import mo
import openvino
import openvino as ov
import nncf
from rich.progress import track
from ultralytics import YOLO
from ultralytics.models.yolo.detect import DetectionValidator
from ultralytics.data.converter import coco80_to_coco91_class
from ultralytics.data.utils import check_det_dataset
from ultralytics.utils.metrics import ConfusionMatrix

def export_yolo(model_name, model_type, output_dir):
    model_dir = os.path.join(output_dir, "object_detection", model_name)
    os.makedirs(model_dir, exist_ok=True)
    weights = model_name + ".pt"
    model = YOLO(weights)
    model.info()
    converted_path = model.export(format='openvino')
    converted_model = os.path.join(converted_path, model_name + '.xml')
    core = openvino.Core()
    ov_model = core.read_model(model=converted_model)
    if model_type in ["YOLOv8-SEG", "yolo_v11_seg"]:
        ov_model.output(0).set_names({"boxes"})
        ov_model.output(1).set_names({"masks"})
    ov_model.set_rt_info(model_type, ['model_info', 'model_type'])
    os.makedirs(os.path.join(model_dir, "FP32"), exist_ok=True)
    os.makedirs(os.path.join(model_dir, "FP16"), exist_ok=True)
    openvino.save_model(ov_model, os.path.join(model_dir, "FP32", model_name + ".xml"), compress_to_fp16=False)
    openvino.save_model(ov_model, os.path.join(model_dir, "FP16", model_name + ".xml"), compress_to_fp16=True)
    shutil.rmtree(converted_path)
    if os.path.exists(weights):
        os.remove(weights)

def quantize_yolo(model_name, dataset_manifest, output_dir):
    model_dir = os.path.join(output_dir, "object_detection", model_name)
    fp32_xml = os.path.join(model_dir, "FP32", model_name + ".xml")
    int8_dir = os.path.join(model_dir, "INT8")
    os.makedirs(int8_dir, exist_ok=True)
    validator = DetectionValidator()
    validator.data = check_det_dataset(dataset_manifest)
    validator.stride = 32
    validator.is_coco = True
    validator.class_map = coco80_to_coco91_class
    data_loader = validator.get_dataloader(validator.data["path"], 1)
    def transform_fn(data_item: dict):
        input_tensor = validator.preprocess(data_item)["img"].numpy()
        return input_tensor
    calibration_dataset = nncf.Dataset(data_loader, transform_fn)
    model = ov.Core().read_model(fp32_xml)
    quantized_model = nncf.quantize(model, calibration_dataset, subset_size=len(data_loader))
    def validate(model, data_loader, validator, num_samples=None):
        validator.seen = 0
        validator.jdict = []
        validator.stats = dict(tp=[], conf=[], pred_cls=[], target_cls=[], target_img=[])
        validator.end2end = False
        validator.confusion_matrix = ConfusionMatrix(validator.data["names"])
        compiled_model = ov.compile_model(model, device_name="CPU")
        output_layer = compiled_model.output(0)
        for batch_i, batch in enumerate(track(data_loader, description="Validating")):
            if num_samples is not None and batch_i == num_samples:
                break
            batch = validator.preprocess(batch)
            preds = torch.from_numpy(compiled_model(batch["img"])[output_layer])
            preds = validator.postprocess(preds)
            validator.update_metrics(preds, batch)
        stats = validator.get_stats()
        return stats, validator.seen
    def print_statistics(stats: dict, total_images: int):
        mp, mr, map50, mean_ap = (
            stats["metrics/precision(B)"],
            stats["metrics/recall(B)"],
            stats["metrics/mAP50(B)"],
            stats["metrics/mAP50-95(B)"],
        )
        s = ("%20s" + "%12s" * 5) % ("Class", "Images", "Precision", "Recall", "mAP@.5", "mAP@.5:.95")
        print(s)
        pf = "%20s" + "%12i" + "%12.3g" * 4
        print(pf % ("all", total_images, mp, mr, map50, mean_ap))
    fp_stats, total_images = validate(model, data_loader, validator)
    print("Floating-point model validation results:")
    print_statistics(fp_stats, total_images)
    q_stats, total_images = validate(quantized_model, data_loader, validator)
    print("Quantized model validation results:")
    print_statistics(q_stats, total_images)
    try:
        map50_drop = (fp_stats["metrics/mAP50(B)"] - q_stats["metrics/mAP50(B)"]) / fp_stats["metrics/mAP50(B)"] * 100
        map95_drop = (fp_stats["metrics/mAP50-95(B)"] - q_stats["metrics/mAP50-95(B)"]) / fp_stats["metrics/mAP50-95(B)"] * 100
        print(f"mAP@.5 accuracy drop: {map50_drop:.2f}%")
        print(f"mAP@.5:.95 accuracy drop: {map95_drop:.2f}%")
    except Exception as e:
        print(f"[WARN] Could not compute accuracy drop: {e}")
    quantized_model.set_rt_info(ov.get_version(), "Runtime_version")
    xml_path = os.path.join(int8_dir, model_name + ".xml")
    bin_path = os.path.join(int8_dir, model_name + ".bin")
    ov.save_model(quantized_model, xml_path, compress_to_fp16=False)
    fp32_bin = os.path.join(model_dir, "FP32", model_name + ".bin")
    if os.path.exists(fp32_bin) and not os.path.exists(bin_path):
        shutil.copy(fp32_bin, bin_path)
    for d in ["datasets", "runs"]:
        p = os.path.join(output_dir, d)
        if os.path.exists(p):
            shutil.rmtree(p)
        p2 = os.path.join(model_dir, d)
        if os.path.exists(p2):
            shutil.rmtree(p2)

def export_classification(model_name, output_dir):
    model_dir = os.path.join(output_dir, "object_classification", model_name)
    os.makedirs(model_dir, exist_ok=True)
    model = timm.create_model(model_name, pretrained=True)
    model.eval()
    dummy = torch.randn(1, 3, 224, 224)
    onnx_path = os.path.join(model_dir, f"{model_name}.onnx")
    torch.onnx.export(model, dummy, onnx_path, input_names=["input"], output_names=["output"], opset_version=12)
    print(f"Exported {model_name} to ONNX: {onnx_path}")
    mo.convert(input_model=onnx_path, output_dir=os.path.join(model_dir, "FP32"), data_type="FP32")

def download_face_detection(model_name, output_dir):
    model_dir = os.path.join(output_dir, "face_detection", model_name)
    os.makedirs(model_dir, exist_ok=True)
    subprocess.run(["omz_downloader", "--name", model_name, "--output_dir", model_dir], check=True)
    subprocess.run(["omz_converter", "--name", model_name, "--precisions", "FP32", "--download_dir", model_dir, "--output_dir", os.path.join(model_dir, "FP32")], check=True)

def download_all(config_path, output_dir):
    with open(config_path) as f:
        config = json.load(f)
    for workload in config.get("workloads", []):
        model_name = workload["model_name"]
        model_category = workload["model_type"]
        if model_category == "object_detection":
            model_path = os.path.join(output_dir, "object_detection", model_name, "FP32", f"{model_name}.xml")
            if os.path.exists(model_path):
                print(f"[INFO] Model {model_name} ({model_category}) already exists at {model_path}, skipping download.")
                continue
            print(f"[INFO] Downloading/converting {model_name} ({model_category}) ...")
            export_yolo(model_name, model_category, output_dir)
            # Quantize if needed
            quant_dataset = os.path.join(output_dir, "datasets", "coco128.yaml")
            if not os.path.exists(quant_dataset):
                os.makedirs(os.path.dirname(quant_dataset), exist_ok=True)
                url = "https://raw.githubusercontent.com/ultralytics/ultralytics/v8.1.0/ultralytics/cfg/datasets/coco128.yaml"
                subprocess.run(["wget", "--timeout=30", "--tries=2", url, "-O", quant_dataset], check=True)
            quantize_yolo(model_name, quant_dataset, output_dir)
        elif model_category == "object_classification":
            model_path = os.path.join(output_dir, "object_classification", model_name, "FP32", f"{model_name}.xml")
            if os.path.exists(model_path):
                print(f"[INFO] Model {model_name} ({model_category}) already exists at {model_path}, skipping download.")
                continue
            print(f"[INFO] Downloading/converting {model_name} ({model_category}) ...")
            export_classification(model_name, output_dir)
        elif model_category == "face_detection":
            model_path = os.path.join(output_dir, "face_detection", model_name, "FP32", f"{model_name}.xml")
            if os.path.exists(model_path):
                print(f"[INFO] Model {model_name} ({model_category}) already exists at {model_path}, skipping download.")
                continue
            print(f"[INFO] Downloading/converting {model_name} ({model_category}) ...")
            download_face_detection(model_name, output_dir)
        else:
            print(f"[WARN] Unsupported model category: {model_category}, skipping...")
    print("###################### Model downloading has been completed successfully #########################")

def main():
    if len(sys.argv) < 2:
        print("Usage: model_convert.py <command> ...")
        sys.exit(1)
    cmd = sys.argv[1]
    if cmd == "export_yolo":
        if len(sys.argv) < 5:
            print("Usage: model_convert.py export_yolo <model_name> <model_type> <output_dir>")
            sys.exit(1)
        export_yolo(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == "quantize_yolo":
        if len(sys.argv) < 5:
            print("Usage: model_convert.py quantize_yolo <model_name> <dataset_manifest> <output_dir>")
            sys.exit(1)
        quantize_yolo(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == "object_classification":
        if len(sys.argv) < 4:
            print("Usage: model_convert.py object_classification <model_name> <output_dir>")
            sys.exit(1)
        export_classification(sys.argv[2], sys.argv[3])
    elif cmd == "download_all":
        if len(sys.argv) < 4:
            print("Usage: model_convert.py download_all <config_path> <output_dir>")
            sys.exit(1)
        download_all(sys.argv[2], sys.argv[3])
    else:
        print(f"[ERROR] Unsupported command: {cmd}")
        sys.exit(2)

if __name__ == "__main__":
    main()
