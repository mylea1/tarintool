FROM pytorch/pytorch:2.5.1-cuda12.4-cudnn9-runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    KILO_MODEL_PATH=/opt/kilo/models/yolo11s-pose.pt \
    KILO_INFERENCE_IMAGE_SIZE=960

RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg libglib2.0-0 libgl1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/kilo/worker

COPY requirements.txt ./requirements.txt
RUN pip install --no-cache-dir \
      --index-url https://mirrors.ustc.edu.cn/pypi/simple \
      -r requirements.txt

RUN mkdir -p /opt/kilo/models \
    && python -c "from ultralytics import YOLO; YOLO('yolo11s-pose.pt')" \
    && mv yolo11s-pose.pt /opt/kilo/models/yolo11s-pose.pt

COPY . .

RUN useradd --create-home --uid 10001 kilo \
    && chown -R kilo:kilo /opt/kilo

USER kilo

CMD ["python", "worker.py"]
