# Kopi Kita POS — Panduan Fitur Aplikasi

> Aplikasi kasir berbasis Flutter untuk coffee shop. Data tersimpan lokal di perangkat (SQLite), tidak memerlukan koneksi internet.

---

## Daftar Isi

1. [Dashboard](#1-dashboard)
2. [Kasir (Point of Sale)](#2-kasir-point-of-sale)
3. [Keranjang & Pembayaran](#3-keranjang--pembayaran)
4. [Antrian Pesanan](#4-antrian-pesanan)
5. [Manajemen Menu](#5-manajemen-menu)
6. [Riwayat Transaksi](#6-riwayat-transaksi)
7. [Export Excel](#7-export-excel)
8. [Laporan & Analitik](#8-laporan--analitik)
9. [Printer & Struk](#9-printer--struk)
10. [Reset Database](#10-reset-database)

---

## Navigasi Utama

Aplikasi memiliki **4 tab** di bagian bawah layar:

| Tab | Ikon | Fungsi |
|---|---|---|
| **Dashboard** | 🏠 | Ringkasan performa hari ini |
| **Kasir** | 🛒 | Buka transaksi baru |
| **Pesanan** | 🧾 | Antrian & status pesanan |
| **Lainnya** | ⋯ | Menu, riwayat, export, laporan, printer |

---

## 1. Dashboard

Halaman pertama yang muncul saat aplikasi dibuka. Menampilkan ringkasan bisnis **hari ini secara real-time**.

### Metrik Utama

| Kartu | Penjelasan |
|---|---|
| **Omzet Hari Ini** | Total penjualan hari ini |
| **Transaksi Hari Ini** | Jumlah order yang sudah dibayar |

### Widget Tambahan

- **Grafik Omzet 7 Hari** — bar chart tren penjualan dari H-6 hingga hari ini
- **Produk Terlaris** — top 5 menu berdasarkan total kuantitas terjual
- Tombol **Lihat Laporan & Analitik** untuk masuk ke halaman laporan

---

## 2. Kasir (Point of Sale)

Halaman utama untuk melayani pelanggan dan membuat pesanan.

### Cara Kerja

1. Gunakan **search bar** untuk mencari nama menu
2. Gunakan **filter kategori** untuk mempersempit pilihan:
   - Semua · Kopi · Non Kopi · Makanan · Add-on
3. Tap produk untuk menambahkan ke keranjang

### Kustomisasi Menu Minuman

Khusus produk minuman (**Kopi** & **Non Kopi**), muncul halaman kustomisasi sebelum masuk ke keranjang (seluruh minuman disajikan dingin/ice):

| Opsi | Pilihan |
|---|---|
| Tingkat Es | Normal Ice / Less Ice |
| Tingkat Gula | Normal Sugar / Less Sugar |
| Add-on | Sesuai yang diatur per produk (misal: Extra Shot, Extra Susu, Topping) |
| Catatan | Teks bebas, maksimal 100 karakter |

> Pilihan add-on otomatis mengubah harga akhir item.

---

## 3. Keranjang & Pembayaran

### Halaman Keranjang

- Input **nama pembeli** (akan tercetak di struk)
- Edit jumlah item atau hapus item dari keranjang
- Tampil ringkasan: subtotal · diskon · **total pembayaran**

### Halaman Pembayaran

Pilih metode pembayaran:

| Metode | Detail |
|---|---|
| **Tunai** | Input nominal diterima → kembalian dihitung otomatis. Tombol cepat: Rp 50.000 / 100.000 / 150.000 / 200.000 |
| **QRIS** | Konfirmasi langsung |

Setelah **Bayar Sekarang**:
- Transaksi tersimpan ke database
- Struk dicetak otomatis (jika printer terhubung)
- Nomor transaksi unik dibuat otomatis (format: `TRX-{nomor order}{DDMMYYHHmm}`)

### Halaman Sukses

- Ringkasan transaksi: nomor, metode, nama pembeli, total
- Tombol **Cetak Struk** untuk cetak ulang
- Tombol **Transaksi Baru** untuk langsung kembali ke kasir

---

## 4. Antrian Pesanan

Halaman untuk memantau dan mengupdate status pesanan — berguna jika kasir dan barista terpisah.

### Alur Status Pesanan

```
Baru  →  Dibuat  →  Selesai  →  Diambil
```

- Tap tombol di setiap kartu untuk menggeser status ke tahap berikutnya
- Menampilkan 100 transaksi terakhir
- Setiap kartu menampilkan: nomor order, nama pelanggan, metode bayar, total, dan status saat ini

---

## 5. Manajemen Menu

Akses dari tab **Lainnya**, di bagian atas halaman.

### Tambah Menu Baru

Isi form:
- Nama dan kategori (Kopi / Non Kopi / Makanan / Add-on)
- Harga jual
- Foto produk (dari galeri/file, maks. 5 MB)
- Default es dan gula *(khusus kategori Kopi & Non Kopi)*
- **Add-on** eksklusif produk (nama + harga, bisa lebih dari satu, opsional) *(untuk kategori Kopi, Non Kopi, dan Makanan)*

### Kelola Menu yang Ada

| Aksi | Cara |
|---|---|
| **Toggle Tersedia** | Switch on/off di daftar menu — nonaktifkan tanpa hapus |
| **Edit** | Popup menu → Edit |
| **Hapus** | Popup menu → Hapus, dengan konfirmasi |

---

## 6. Riwayat Transaksi

Akses dari tab **Lainnya → Riwayat Transaksi**.

- Menampilkan 100 transaksi terakhir dalam daftar yang bisa di-expand
- Setiap transaksi menampilkan: nomor, nama pelanggan, metode bayar, tanggal/jam, total
- Expand untuk melihat **detail item** per transaksi (nama produk, kustomisasi, qty, subtotal)
- Tombol **Cetak Ulang** untuk mencetak kembali struk transaksi tersebut

---

## 7. Export Excel

Akses dari tab **Lainnya → Export Excel**.

Fitur untuk mengekspor rekap transaksi ke file `.xlsx` yang bisa dibagikan via WhatsApp, email, Google Drive, atau disimpan langsung ke perangkat.

### Filter Periode

Pilih salah satu dari tiga mode:

| Mode | Cara Kerja |
|---|---|
| **Mingguan** | Navigasi maju/mundur per minggu (Senin–Minggu) menggunakan tombol `‹` dan `›` |
| **Bulanan** | Pilih bulan dan tahun dari dropdown |
| **Rentang Bulan** | Pilih bulan awal dan bulan akhir secara terpisah — bisa lintas tahun |

### Isi File Excel (3 Sheet)

| Sheet | Kolom |
|---|---|
| **Ringkasan Transaksi** | No. Transaksi · Tanggal · Jam · Nama Pelanggan · Metode Bayar · Total (Rp) · Status |
| **Detail Item** | No. Transaksi · Tanggal · Jam · Pelanggan · Produk · Kustomisasi · Catatan · Qty · Harga Satuan · Surcharge · Subtotal |
| **Rekap Harian** | Tanggal · Jumlah Transaksi · Total Omzet (Rp) |

Setiap sheet dilengkapi baris **TOTAL** di bagian bawah dan header berwarna coklat.

### Cara Export

1. Pilih mode periode
2. Pilih rentang waktu yang diinginkan
3. Tap **Export Excel**
4. Di PC, pilih folder dan nama file. Di perangkat lain, pilih tujuan berbagi.

> Jika tidak ada transaksi pada periode yang dipilih, akan muncul notifikasi.

---

## 8. Laporan & Analitik

Akses dari tab **Dashboard → Lihat Laporan & Analitik** atau tab **Lainnya → Laporan & Analitik**.

- Metrik omzet dan jumlah transaksi hari ini
- Grafik tren omzet 7 hari terakhir
- Daftar 5 produk terlaris

---

## 9. Printer & Struk

Akses dari tab **Lainnya → Pengaturan Printer**.

### Jenis Printer yang Didukung

| Jenis | Platform |
|---|---|
| **ESC/POS Thermal (Bluetooth)** | Android |
| **USB / Printer Sistem** | Windows & Android |
| **PDF 80mm** | Semua platform (fallback) |

### Cara Hubungkan Printer

1. Tap **Pair Bluetooth** atau **Tambah USB** untuk membuka pengaturan sistem
2. Pair printer dari pengaturan sistem perangkat
3. Kembali ke app → tap **Deteksi Ulang** (ikon refresh)
4. Tap nama printer untuk memilihnya sebagai printer aktif
5. Atau gunakan **Buka Pemilih Printer Sistem** untuk memilih dari daftar sistem

### Isi Struk

- Nama & alamat toko
- Nomor transaksi & tanggal/jam
- Nama pembeli & metode pembayaran
- Daftar item (nama, kustomisasi, catatan, subtotal per baris)
- Subtotal · Diskon · Pajak · **Total**
- Pesan terima kasih

---

## 10. Reset Database

Tersedia di tab **Lainnya → Reset Database**.

> ⚠️ **Peringatan:** Tindakan ini akan menghapus **semua data** termasuk produk, menu, dan seluruh riwayat transaksi. Tidak bisa dibatalkan. Akan muncul dialog konfirmasi sebelum proses berjalan.

---

## Catatan Teknis

| Aspek | Detail |
|---|---|
| **Platform** | Android & Windows |
| **Database** | SQLite lokal (tidak butuh internet) |
| **Format Export** | `.xlsx` (Microsoft Excel / Google Sheets) |
| **Diskon & Pajak** | Tampil di struk namun belum aktif (Rp 0) |

---

*Kopi Kita POS — dibuat dengan Flutter*
