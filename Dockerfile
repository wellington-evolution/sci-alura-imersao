# syntax=docker/dockerfile:1

# --- Builder Stage ---
# This stage installs dependencies and builds wheels.
FROM python:3.13-slim-bullseye AS builder

# Set environment variables for Python
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install dependencies into a wheelhouse
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt


# --- Production Stage ---
# This stage creates the final, lean production image.
FROM python:3.13-slim-bullseye

# Set environment variables for Python
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Create a non-root user for security
RUN addgroup --system app && adduser --system --ingroup app app

# Create and set the working directory
WORKDIR /home/app

# Copy dependencies from the builder stage and install them
COPY --from=builder /wheels /wheels
COPY --from=builder /app/requirements.txt .
RUN pip install --no-cache-dir /wheels/*

# Copy the application source code
COPY . .

# Change ownership of the app directory to the non-root user
RUN chown -R app:app .

# Switch to the non-root user
USER app

# Expose the specified port
EXPOSE $PORT

# Run the application using uvicorn
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "${PORT}"]
