#!/bin/bash

# =============================================================================
# SCRIPT DE EJECUCIÓN COMPLETA DEL ANÁLISIS DE CONSISTENCIA
# =============================================================================
# Este script ejecuta todo el pipeline de análisis de consistencia
# Autor: GitHub Copilot
# Fecha: 2025-09-19
# =============================================================================

echo "=================================================="
echo "  ANÁLISIS DE CONSISTENCIA - BIODIVERSIDAD GOC"
echo "=================================================="
echo "Fecha: $(date)"
echo ""

# Cambiar al directorio de scripts
cd "$(dirname "$0")/scripts"

echo "1. Ejecutando análisis de consistencia principal..."
echo "----------------------------------------------------"
if Rscript analisis_consistencia_bd.R; then
    echo "✓ Análisis de consistencia completado exitosamente"
else
    echo "✗ Error en análisis de consistencia"
    exit 1
fi

echo ""
echo "2. Generando visualizaciones..."
echo "-------------------------------"
if Rscript generar_visualizaciones.R; then
    echo "✓ Visualizaciones generadas exitosamente"
else
    echo "⚠ Error generando visualizaciones (continuando...)"
fi

echo ""
echo "=================================================="
echo "          REPORTE COMPLETADO"
echo "=================================================="
echo ""
echo "Archivos generados en:"
echo "  $(pwd)/../"
echo ""
echo "Contenido principal:"
echo "  📄 consistency_analysis_report_2025-09-19.txt"
echo "  📄 conabio_integration_report_2025-09-19.txt"
echo "  📊 data/consistency_summary_2025-09-19.csv"
echo "  📊 data/biodiversity_integrated_conabio_2025-09-19.csv (enlace)"
echo "  🖼️ visualizations/ (si se generaron exitosamente)"
echo "  💻 scripts/ (todos los scripts R)"
echo "  📖 README.md (documentación completa)"
echo "  📋 metadata.yml (metadatos del análisis)"
echo ""
echo "Para revisar el reporte principal:"
echo "  cat ../consistency_analysis_report_2025-09-19.txt"
echo ""
echo "Para revisar el resumen estadístico:"
echo "  cat ../data/consistency_summary_2025-09-19.csv"
echo ""
echo "=================================================="