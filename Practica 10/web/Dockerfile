# ============================================
# Práctica 10 - Servidor Web Personalizado
# Base: Alpine Linux (imagen ligera)
# Servicio: Nginx
# ============================================

# 1. Imagen base ligera
FROM nginx:alpine

# 2. Metadatos
LABEL maintainer="Berrelleza"
LABEL description="Servidor web Nginx sobre Alpine - Practica 10"

# 3. Eliminar configuración por defecto de Nginx
RUN rm /etc/nginx/conf.d/default.conf && \
    rm /etc/nginx/nginx.conf

# 4. Copiar nuestra configuración personalizada
COPY nginx.conf /etc/nginx/nginx.conf

# 5. Copiar los archivos del sitio web
COPY site/ /usr/share/nginx/html/

# 6. Crear directorios necesarios y dar permisos al usuario nginx
#    (el usuario 'nginx' ya existe en la imagen base)
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid

# 7. Cambiar al usuario no-root
USER nginx

# 8. Exponer el puerto 8080 (no-root no puede usar < 1024)
EXPOSE 8080

# 9. Comando que se ejecuta al iniciar el contenedor
CMD ["nginx", "-g", "daemon off;"]