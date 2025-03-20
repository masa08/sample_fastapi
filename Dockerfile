FROM continuumio/miniconda3:latest

WORKDIR /app

COPY environment.yaml .

# Setup a conda environment
RUN conda env create -f environment.yaml
ENV PATH="/opt/conda/envs/metadata-service/bin:$PATH"

COPY . .

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080", "--reload"]