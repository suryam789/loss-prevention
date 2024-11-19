#
# Copyright (C) 2024 Intel Corporation.
#
# SPDX-License-Identifier: Apache-2.0
#

FROM python:3.9-slim
ENV PYTHONUNBUFFERED=1
WORKDIR /app
COPY . .
RUN pip install paho-mqtt==1.6.1 Flask
CMD ["python", "loss_prevention.py"]
