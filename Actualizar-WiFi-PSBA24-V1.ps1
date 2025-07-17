# Ruta para almacenar el controlador descargado localmente
$driverFolder = "C:\ProgramData\ActualizarWLAN"
$desiredVersion = "2024.10.230.2"
$adapterName = "Realtek 8822CE Wireless LAN 802.11ac PCI-E NIC"
$zipFile = Join-Path $driverFolder "driver-wifi-PSBA24.zip"
$downloadUrl = "https://github.com/Lycan07/downloads/releases/download/v2.0/realtek-8822ce.zip"
$driverUpdated = $false

# Crear la carpeta si no existe
If (-not (Test-Path $driverFolder)) {
    New-Item -Path $driverFolder -ItemType Directory -Force | Out-Null
}

# Descargar el archivo ZIP si no existe
if (-not (Test-Path $zipFile)) {
    Write-Host "Descargando el controlador (3 intentos máximo)..."
    $maxRetries = 3
    $retryDelay = 5
    $attempt = 0
    $downloaded = $false

    while (-not $downloaded -and $attempt -lt $maxRetries) {
        $attempt++
        Try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile -ErrorAction Stop
            Write-Host "Descarga completada: $zipFile"
            $downloaded = $true
        } Catch {
            Write-Warning "Error al descargar (intento $attempt): $_"
            if ($attempt -lt $maxRetries) {
                Start-Sleep -Seconds $retryDelay
            }
        }
    }

    if (-not $downloaded) {
        Write-Warning "No se pudo descargar el archivo después de $maxRetries intentos."
        exit 1
    }
} else {
    Write-Host "Archivo ZIP ya existe. Se usará la copia local: $zipFile"
}

# Forzar extracción del ZIP para actualizar todos los archivos
Write-Host "Extrayendo archivo ZIP..."
Try {
    Expand-Archive -Path $zipFile -DestinationPath $driverFolder -Force
    Write-Host "Extracción completada."
} Catch {
    Write-Warning "Error al extraer el archivo ZIP: $_"
    exit 1
}

# Buscar el adaptador por nombre
$adapter = Get-WmiObject Win32_PnPSignedDriver | Where-Object {
    $_.DeviceName -eq $adapterName
}

if ($adapter) {
    $installedVersion = $adapter.DriverVersion
    $infName = $adapter.InfName
    Write-Host "Versión instalada actualmente: $installedVersion (INF: $infName)"

    if ($installedVersion -ne $desiredVersion) {
        Write-Host "Versión diferente detectada. Procediendo a reemplazar controlador."

        Try {
            & pnputil /delete-driver $infName /uninstall /force
            Write-Host "Controlador desinstalado correctamente."
        } Catch {
            Write-Warning "No se pudo desinstalar el controlador actual: $_"
        }

        # Buscar el nuevo INF extraído
        $nuevoINF = Get-ChildItem -Path $driverFolder -Recurse -Filter "netrtwlane.inf" | Select-Object -First 1

        If ($nuevoINF) {
            Try {
                & pnputil /add-driver $nuevoINF.FullName /install
                Write-Host "Nuevo controlador instalado correctamente."
                $driverUpdated = $true
            } Catch {
                Write-Warning "Error al instalar el nuevo controlador: $_"
                exit 1
            }
        } else {
            Write-Warning "No se encontró el archivo INF para instalar."
            exit 1
        }
    } else {
        Write-Host "La versión instalada ya es la correcta. No se realiza ninguna acción."
    }
} else {
    Write-Warning "No se encontró el adaptador '$adapterName'."
    exit 1
}

Write-Host "Proceso finalizado."

# Reiniciar si se actualizó el controlador
if ($driverUpdated) {
    Write-Host "Reinicio forzado en 30 segundos por mantenimiento crítico. Guardá tus tareas."
    Start-Process -FilePath "shutdown.exe" -ArgumentList "/r /t 30 /c `"Reinicio forzado en 30 segundos por mantenimiento crítico. Guardá tus tareas.`""
}

exit 0

exit 0
