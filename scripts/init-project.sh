#!/bin/bash

set -e

PROJECT_PATH=$1
INSTANCE_NAME=$(basename "$PROJECT_PATH")

if [ $# -ne 1 ]; then
    echo "Usage:"
    echo "./init-project.sh <project-path>"
    exit 1
fi


TEMPLATE_PATH="/opt/mini-odoo-sh/templates/project"


if [ ! -d "$TEMPLATE_PATH" ]; then
    echo "Template does not exist:"
    echo "$TEMPLATE_PATH"
    exit 1
fi


if [ ! -d "$PROJECT_PATH" ]; then
    echo "Creating project directory..."
    mkdir -p "$PROJECT_PATH"
fi


echo "Initializing Odoo project..."


cp -rn "$TEMPLATE_PATH/"* "$PROJECT_PATH/"

# Copy hidden files (.github)
cp -rn "$TEMPLATE_PATH/.github" "$PROJECT_PATH/"

echo "Project initialized successfully."

echo ""
echo "Created:"
echo "- addons/"
echo "- config/"
echo "- .github/workflows/"
echo "- README.md"

echo "Configuring deployment workflow..."


sed -i \
"s/{{INSTANCE_NAME}}/$INSTANCE_NAME/g" \
"$PROJECT_PATH/.github/workflows/deploy.yml"
