#!/bin/bash

echo "🧪 Probando mejoras en generador_poligono.R"
echo "=============================================="
echo

# Verificar sintaxis
echo "📝 Verificando sintaxis del archivo..."
Rscript -e "
tryCatch({
  source('generador_poligono.R', echo=FALSE)
  cat('✅ Sintaxis correcta\n')
}, error = function(e) {
  cat('❌ Error de sintaxis:', e$message, '\n')
  quit(status=1)
})"

if [ $? -eq 0 ]; then
    echo
    echo "🚀 Iniciando aplicación de prueba..."
    echo "📱 La aplicación se abrirá en tu navegador"
    echo "🔍 Prueba las siguientes funcionalidades:"
    echo "   1. 📐 Dibuja un polígono en el mapa"
    echo "   2. 📊 Ve a 'Consulta Biodiversidad' y observa la información del grid"
    echo "   3. 🔧 Cambia el tamaño del grid y observa cómo se actualiza la información"
    echo "   4. 📖 Lee las leyendas explicativas de cada parámetro"
    echo "   5. 🎯 Ejecuta una consulta y observa el tamaño reducido de los puntos"
    echo
    echo "⏹️  Presiona Ctrl+C para detener la aplicación"
    echo
    
    # Ejecutar la aplicación
    Rscript generador_poligono.R
else
    echo "❌ No se puede ejecutar debido a errores de sintaxis"
fi
