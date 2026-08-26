#!/bin/bash
set -euo pipefail

echo ""
echo "|--------------------------------------------------------------------------------------|"
echo "| cc-docker dev environment reset script                                               |"
echo "| This will stop all containers, remove volumes, and delete all generated data.        |"
echo "| After completion, re-run ./setupDev.sh to reinitialize.                              |"
echo "|--------------------------------------------------------------------------------------|"
echo ""

read -p "This will delete all generated data and cannot be undone. Continue? [y/N] " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

DOCKER_COMPOSE=""

if docker-compose --version &>/dev/null 2>&1; then
    DOCKER_COMPOSE="docker-compose"
fi

if docker compose version &>/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
fi

if [[ -z "${DOCKER_COMPOSE}" ]]; then
    echo "docker-compose not found!"
    exit 1
fi

echo "Stopping containers and removing volumes..."
$DOCKER_COMPOSE down --volumes --remove-orphans

echo "Removing data directory..."
if [ -d data ]; then
    rm -rf data
fi

echo "Removing cc-backend generated files..."
if [ -d cc-backend/var ]; then
    rm -rf cc-backend/var
fi
if [ -f cc-backend/.env ]; then
    rm cc-backend/.env
fi
if [ -f cc-backend/config.json ]; then
    rm cc-backend/config.json
fi

echo ""
echo "|--------------------------------------------------------------------------------------|"
echo "| Reset complete.                                                                       |"
echo "| Run ./setupDev.sh to reinitialize the dev environment.                               |"
echo "| To also remove built Docker images, run: docker-compose down --rmi all              |"
echo "|--------------------------------------------------------------------------------------|"
echo ""
