services:
  postgres:
    image: postgres:16
    container_name: {{INSTANCE_NAME}}-postgres
    restart: unless-stopped

    environment:
      POSTGRES_DB: postgres
      POSTGRES_USER: odoo
      POSTGRES_PASSWORD: odoo

    volumes:
      - postgres-data:/var/lib/postgresql/data

  odoo:
    image: odoo:18
    container_name: {{INSTANCE_NAME}}-odoo
    restart: unless-stopped

    depends_on:
      - postgres

    ports:
      - "{{ODOO_PORT}}:8069"

    environment:
      HOST: postgres
      USER: odoo
      PASSWORD: odoo

    volumes:
      - odoo-data:/var/lib/odoo
      - ./addons:/mnt/extra-addons
      - ./config:/etc/odoo

volumes:
  postgres-data:
  odoo-data:
