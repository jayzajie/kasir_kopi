package com.example.kasir_kopi

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val spp = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kopi_kita/device_settings")
            .setMethodCallHandler(::handlePrinterCall)
    }

    private fun handlePrinterCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openPrinterSettings" -> {
                val action = if (call.arguments as? String == "bluetooth") {
                    Settings.ACTION_BLUETOOTH_SETTINGS
                } else {
                    Settings.ACTION_PRINT_SETTINGS
                }
                startActivity(Intent(action))
                result.success(null)
            }
            "listBluetoothPrinters" -> listBluetoothPrinters(result)
            "rawPrint" -> rawPrint(call, result)
            else -> result.notImplemented()
        }
    }

    private fun ensureBluetoothPermission(result: MethodChannel.Result): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            (checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED &&
                checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED)
        ) return true

        requestPermissions(
            arrayOf(
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_SCAN,
            ),
            1001,
        )
        result.error("PERMISSION_REQUIRED", "Izinkan Perangkat di sekitar, lalu tekan Deteksi Ulang.", null)
        return false
    }

    @Suppress("DEPRECATION", "MissingPermission")
    private fun listBluetoothPrinters(result: MethodChannel.Result) {
        if (!ensureBluetoothPermission(result)) return
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null) {
            result.error("NO_BLUETOOTH", "HP ini tidak memiliki Bluetooth.", null)
            return
        }
        if (!adapter.isEnabled) {
            result.error("BLUETOOTH_OFF", "Nyalakan Bluetooth terlebih dahulu.", null)
            return
        }
        result.success(adapter.bondedDevices.map { mapOf("name" to (it.name ?: it.address), "address" to it.address) })
    }

    @Suppress("DEPRECATION", "MissingPermission")
    private fun rawPrint(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureBluetoothPermission(result)) return
        val args = call.arguments as? Map<*, *>
        val address = args?.get("printerName") as? String
        val data = args?.get("data") as? ByteArray
        if (address.isNullOrBlank() || data == null || data.isEmpty()) {
            result.error("INVALID_ARGS", "Alamat printer atau data struk kosong.", null)
            return
        }

        Thread {
            try {
                val adapter = BluetoothAdapter.getDefaultAdapter()
                    ?: throw IllegalStateException("Bluetooth tidak tersedia")
                adapter.cancelDiscovery()
                val device = adapter.getRemoteDevice(address)
                val socket = connect(device)
                socket.use {
                    it.outputStream.write(data)
                    it.outputStream.flush()
                }
                runOnUiThread { result.success(null) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error(
                        "PRINT_FAILED",
                        "Gagal terhubung ke printer: ${error.message}",
                        null,
                    )
                }
            }
        }.start()
    }

    @Suppress("MissingPermission")
    private fun connect(device: BluetoothDevice): android.bluetooth.BluetoothSocket {
        val secure = device.createRfcommSocketToServiceRecord(spp)
        try {
            secure.connect()
            return secure
        } catch (_: Exception) {
            secure.close()
            return device.createInsecureRfcommSocketToServiceRecord(spp).apply { connect() }
        }
    }
}
