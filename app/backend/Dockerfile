FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y curl

RUN curl -LsSf https://astral.sh/uv/install.sh | sh

ENV PATH="/root/.local/bin:$PATH"

COPY pyproject.toml uv.lock .
RUN uv sync --frozen --no-dev

COPY . .

EXPOSE 7001

CMD ["uv", "run", "app.py"]