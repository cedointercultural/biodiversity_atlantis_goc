#!/bin/bash

# ============================================================================
# Script: run_maxima_background.sh
# Descripción: Ejecutar consulta de biodiversidad en background con apagado automático
# Fecha: 2025-10-22
# ============================================================================

cd /home/atlantis/biodiversity_atlantis_goc

# Crear directorio de logs si no existe
mkdir -p logs

# Configurar variables
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="logs/maxima_query_background_${TIMESTAMP}.log"
PID_FILE="logs/maxima_query.pid"
STATUS_FILE="logs/query_status.txt"

echo "═══════════════════════════════════════════════════════════════"
echo "🚀 INICIANDO CONSULTA MÁXIMA EN BACKGROUND CON APAGADO AUTOMÁTICO"
echo "═══════════════════════════════════════════════════════════════"
echo "📅 Fecha/Hora: $(date)"
echo "📁 Directorio: $(pwd)"
echo "📝 Log: $LOG_FILE"
echo "🔢 PID File: $PID_FILE"
echo "⚙️  Configuración: 15,000 registros por celda"
echo "🗃️ Bases de datos: GBIF, OBIS, iDigBio, iNaturalist"
echo "⏱️ Tiempo estimado: 60-90 minutos"
echo "🔌 Apagado automático: HABILITADO"
echo "═══════════════════════════════════════════════════════════════"

# Función para limpiar al terminar
cleanup() {
    echo "🧹 Limpiando archivos temporales..."
    rm -f "$PID_FILE"
}

# Configurar trap para limpieza
trap cleanup EXIT

# Escribir estado inicial
echo "INICIADO|$(date)|$LOG_FILE" > "$STATUS_FILE"

# Ejecutar en background con nohup
nohup bash -c "
    echo '🚀 INICIANDO PROCESO DE CONSULTA MÁXIMA'
    echo '═══════════════════════════════════════════════════════════════'
    echo '📅 Inicio: $(date)'
    echo '📊 Configuración: 15,000 registros por celda'
    echo '🔄 Bases de datos: GBIF, OBIS, iDigBio, iNaturalist'
    echo '📍 Área: Golfo de California (270,423 km²)'
    echo '═══════════════════════════════════════════════════════════════'
    echo ''

    # Cambiar al directorio correcto
    cd /home/atlantis/biodiversity_atlantis_goc

    # Ejecutar la consulta
    Rscript -e \"
        cat('🚀 Cargando sistema de consultas...\\n')
        source('scripts/biodiversity_query.R')
        
        cat('📊 Iniciando consulta máxima...\\n')
        results <- run_biodiversity_query('maxima')
        
        cat('\\n✅ CONSULTA COMPLETADA EXITOSAMENTE\\n')
        cat('📅 Fin:', format(Sys.time(), '%Y-%m-%d %H:%M:%S'), '\\n')
        
        # Verificar resultados
        if (!is.null(results) && !is.null(results\\\$results) && nrow(results\\\$results) > 0) {
            cat('📊 Registros obtenidos:', nrow(results\\\$results), '\\n')
            cat('✅ Archivos generados en: data/query_results/\\n')
        } else {
            cat('⚠️ No se obtuvieron resultados\\n')
        }
    \"
    
    QUERY_EXIT_CODE=\$?
    
    echo ''
    echo '═══════════════════════════════════════════════════════════════'
    echo '📋 RESUMEN FINAL'
    echo '═══════════════════════════════════════════════════════════════'
    echo '📅 Fin del proceso: $(date)'
    echo '🔢 Código de salida: '\$QUERY_EXIT_CODE
    
    if [ \$QUERY_EXIT_CODE -eq 0 ]; then
        echo '✅ Estado: COMPLETADO CON ÉXITO'
        echo 'COMPLETADO|$(date)|Éxito' > logs/query_status.txt
        
        # Mostrar archivos generados
        echo ''
        echo '📁 ARCHIVOS GENERADOS:'
        ls -la data/query_results/*$(date +%Y%m%d)* 2>/dev/null || echo '   No se encontraron archivos de hoy'
        
    else
        echo '❌ Estado: ERROR EN LA EJECUCIÓN'
        echo 'ERROR|$(date)|Código '\$QUERY_EXIT_CODE > logs/query_status.txt
    fi
    
    echo ''
    echo '═══════════════════════════════════════════════════════════════'
    echo '🔌 INICIANDO SECUENCIA DE APAGADO AUTOMÁTICO'
    echo '═══════════════════════════════════════════════════════════════'
    echo '⏰ Apagado programado en 2 minutos...'
    echo '🛑 Para cancelar el apagado: sudo shutdown -c'
    echo ''
    
    # Programar apagado en 2 minutos
    sudo shutdown -h +2 'Consulta de biodiversidad completada. Apagado automático en 2 minutos.'
    
    echo '✅ Comando de apagado ejecutado'
    echo '📝 Log completo guardado en: $LOG_FILE'
    echo ''
    
" > "$LOG_FILE" 2>&1 &

# Guardar PID del proceso background
BACKGROUND_PID=$!
echo $BACKGROUND_PID > "$PID_FILE"

echo ""
echo "✅ PROCESO INICIADO EN BACKGROUND"
echo "🆔 PID: $BACKGROUND_PID"
echo "📝 Log: $LOG_FILE"
echo ""
echo "🔒 PUEDES DESCONECTARTE SAFELY - El proceso continuará ejecutándose"
echo ""
echo "📋 COMANDOS ÚTILES:"
echo "   • Monitorear progreso:    tail -f $LOG_FILE"
echo "   • Ver estado actual:      cat $STATUS_FILE"
echo "   • Ver proceso corriendo:  ps aux | grep $BACKGROUND_PID"
echo "   • Detener proceso:        kill $BACKGROUND_PID"
echo "   • Cancelar apagado:       sudo shutdown -c"
echo ""
echo "🔍 RECONECTARSE Y MONITOREAR:"
echo "   ssh atlantis@dataserver02"
echo "   cd /home/atlantis/biodiversity_atlantis_goc"
echo "   tail -f $LOG_FILE"
echo ""
echo "⚠️  IMPORTANTE:"
echo "   • El sistema se apagará automáticamente 2 min después de completar"
echo "   • Para cancelar apagado: sudo shutdown -c"
echo "   • Logs se guardan en: logs/"
echo ""

# Mostrar progreso inicial por 30 segundos
echo "📊 PROGRESO INICIAL (30 segundos):"
echo "════════════════════════════════════"
sleep 5
if [ -f "$LOG_FILE" ]; then
    timeout 25 tail -f "$LOG_FILE" 2>/dev/null || true
fi

echo ""
echo "🎯 PROCESO CONFIGURADO CORRECTAMENTE"
echo "💡 Ahora puedes cerrar VS Code y desconectarte"
echo "🔌 La máquina se apagará automáticamente al terminar"