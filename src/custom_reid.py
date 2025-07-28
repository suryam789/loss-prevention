import numpy as np

gallery = []
ids = []
next_id = 1

# This function will be called by gvapython for each frame
# frame_meta is a GVA FrameMeta object
# buffer is the GStreamer buffer

def assign_person_id(buffer, frame_meta):
    global gallery, ids, next_id
    for obj in frame_meta.objects:
        # Check for embedding (from gvaclassify)
        emb = getattr(obj, 'embedding', None)
        if emb is not None:
            emb = np.array(emb)
            # Compare with gallery
            if len(gallery) > 0:
                sims = [np.dot(emb, g) / (np.linalg.norm(emb) * np.linalg.norm(g)) for g in gallery]
                max_sim = max(sims)
                if max_sim > 0.8:
                    obj.person_id = ids[sims.index(max_sim)]
                else:
                    obj.person_id = next_id
                    gallery.append(emb)
                    ids.append(next_id)
                    next_id += 1
            else:
                obj.person_id = next_id
                gallery.append(emb)
                ids.append(next_id)
                next_id += 1
    return True
