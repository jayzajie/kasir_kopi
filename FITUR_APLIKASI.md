# Kopi Kita POS — Panduan Fitur Aplikasi

> Aplikasi kasir berbasis Flutter untuk coffee shop. Data tersimpan lokal di perangkat (SQLite), tidak memerlukan koneksi internet.

---

## Daftar Isi

1. [Dashboard](#1-dashboard)
2. [Kasir (Point of Sale)](#2-kasir-point-of-sale)
3. [Keranjang & Pembayaran](#3-keranjang--pembayaran)
4. [Antrian Pesanan](#4-antrian-pesanan)
5. [Manajemen Stok](#5-manajemen-stok)
6. [Resep & HPP](#6-resep--hpp)
7. [Pengeluaran](#7-pengeluaran)
8. [Laporan & Analitik](#8-laporan--analitik)
9. [Riwayat Transaksi](#9-riwayat-transaksi)
10. [Manajemen Menu](#10-manajemen-menu)
11. [Printer & Struk](#11-printer--struk)
12. [Reset Database](#12-reset-database)

---

## 1. Dashboard

Halaman pertama yang muncul saat aplikasi dibuka. Menampilkan ringkasan performa bisnis **hari ini secara real-time**.

### Metrik Utama

| Kartu | Penjelasan |
|---|---|
| **Omzet Hari Ini** | Total penjualan (sebelum dikurangi biaya) |
| **Transaksi Hari Ini** | Jumlah order yang sudah dibayar |
| **Laba Bersih Est.** | Omzet dikurangi HPP produk dan pengeluaran operasional |
| **Pengeluaran** | Total biaya yang sudah dicatat hari ini |

### Grafik & Widget Tambahan

- **Grafik Omzet 7 Hari** — bar chart tren penjualan dari H-6 hingga hari ini
- **Produk Terlaris** — top 5 menu berdasarkan total kuantitas terjual
- **Stok Menipis** — daftar bahan baku yang sudah menyentuh atau melewati batas minimum

---

## 2. Kasir (Point of Sale)

Halaman utama untuk melayani pelanggan dan membuat pesanan.

### Cara Kerja

1. Gunakan **search bar** untuk mencari nama menu
2. Gunakan **filter kategori** untuk mempersempit pilihan:
   - Semua · Kopi · Non Kopi · Makanan · Add-on
3. Tap produk untuk menambahkan ke keranjang

### Kustomisasi Menu Kopi

Khusus produk berkategori **Kopi**, muncul halaman kustomisasi sebelum masuk ke keranjang:

| Opsi | Pilihan |
|---|---|
| Suhu | Panas / Dingin |
| Ukuran | Small (−Rp 2.000) · Medium · Large (+Rp 4.000) |
| Tingkat Es | Normal Ice / Less Ice |
| Tingkat Gula | Normal Sugar / Less Sugar |
| Sirup | Caramel / Vanilla / Gula Aren |
| Add-on | Sesuai yang diatur per produk (misal: Extra Shot, Extra Susu) |
| Catatan | Teks bebas, maksimal 100 karakter |

> Setiap pilihan size dan add-on akan otomatis mengubah harga akhir item.

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
| **Tunai** | Input nominal diterima → kembalian dihitung otomatis. Ada tombol cepat: Rp 50.000 / 100.000 / 150.000 / 200.000 |
| **QRIS** | Konfirmasi langsung |
| **Transfer** | Konfirmasi langsung |

Setelah "Bayar Sekarang":
- Transaksi tersimpan ke database
- **Stok bahan baku terpotong otomatis** sesuai resep produk
- Struk dicetak otomatis (jika printer terhubung)
- Nomor transaksi unik dibuat otomatis (format: `TRX-{timestamp}`)

---

## 4. Antrian Pesanan

Halaman untuk memantau dan mengupdate status pesanan, berguna jika kasir dan barista terpisah.

### Alur Status Pesanan

```
Baru  →  Dibuat  →  Selesai  →  Diambil
```

- Tap tombol di setiap kartu pesanan untuk menggeser statusnya
- Menampilkan 30 transaksi terakhir
- Setiap kartu menampilkan: nomor order, nama pelanggan, metode bayar, dan total

---

## 5. Manajemen Stok

Kelola bahan baku secara lengkap dengan audit trail.

### Ringkasan di Bagian Atas

| Metrik | Penjelasan |
|---|---|
| **Nilai Stok** | Total nilai semua bahan (kuantitas × harga satuan) |
| **Stok Rendah** | Jumlah bahan yang sudah di bawah batas minimum |
| **Bahan Habis** | Jumlah bahan yang stoknya nol |

### Fitur Manajemen Stok

| Fitur | Fungsi |
|---|---|
| **Stok Masuk** | Catat pembelian bahan baru. Stok bertambah, harga beli diperbarui, pengeluaran otomatis tercatat, HPP seluruh produk yang pakai bahan ini dihitung ulang |
| **Penyesuaian Stok** | Koreksi manual dengan alasan (Rusak/tumpah, Dipakai sendiri, Koreksi tambah, dll.) |
| **Stok Opname** | Masukkan jumlah stok fisik sebenarnya — sistem menghitung dan mencatat selisihnya |
| **Tambah Bahan** | Daftarkan bahan baku baru dengan satuan, harga, dan minimum stok |

### Detail Per Bahan

Tap tiap bahan untuk melihat:
- Harga beli per kemasan dan harga satuan terhitung
- Nilai stok bahan tersebut
- **Riwayat 30 pergerakan stok terakhir** — jenis, alasan, tanggal, jumlah masuk/keluar (hijau/merah)

---

## 6. Resep & HPP

Fitur untuk menghitung **Harga Pokok Penjualan (HPP)** secara otomatis berdasarkan resep tiap produk.

### Cara Kerja HPP

#### Langkah 1 — Input Harga Bahan Baku

Masukkan data tiap bahan:
- Nama dan satuan (gram / ml / pcs)
- Harga beli kemasan (misal: Rp 120.000)
- Isi kemasan (misal: 1.000 gram)

Sistem otomatis menghitung **harga satuan**:

```
Harga Satuan = Harga Beli Kemasan ÷ Isi Kemasan

Contoh: Rp 120.000 ÷ 1.000 gram = Rp 120 / gram
```

#### Langkah 2 — Atur Resep Per Produk

Untuk setiap menu, tentukan berapa banyak tiap bahan yang dipakai dalam satu porsi.

#### Langkah 3 — HPP Dihitung Otomatis

```
HPP = Σ (Pemakaian per porsi × Harga Satuan Bahan)
```

**Contoh Cappuccino:**

| Bahan | Pakai | Harga Satuan | Biaya |
|---|---|---|---|
| Biji Kopi | 18 gram | Rp 120/gram | Rp 2.160 |
| Susu Full Cream | 120 ml | Rp 15/ml | Rp 1.800 |
| Cup 12oz | 1 pcs | Rp 500/pcs | Rp 500 |
| Tutup Cup | 1 pcs | Rp 333/pcs | Rp 333 |
| **Total HPP** | | | **Rp 4.793** |

Jika harga jual Cappuccino = Rp 25.000, maka:
- **Margin** = Rp 25.000 − Rp 4.793 = **Rp 20.207 (80,8%)**

#### Update Otomatis

Setiap kali harga beli bahan diperbarui atau stok masuk baru dicatat, **HPP semua produk yang menggunakan bahan tersebut langsung dihitung ulang** — tidak perlu input manual.

### Tampilan Margin Per Produk

- 🟢 **Hijau** — margin positif (harga jual di atas HPP)
- 🔴 **Merah** — margin negatif (harga jual di bawah modal, rugi)

### HPP Manual

Jika resep belum diatur, owner bisa mengisi HPP secara manual langsung di form produk. Nilai ini akan dipakai sampai resep disimpan.

---

## 7. Pengeluaran

Catat semua biaya operasional harian.

### Kategori Pengeluaran

`Bahan` · `Listrik` · `Gas` · `Sewa` · `Gaji` · `Lainnya`

### Penting

> **Pembelian stok bahan baku otomatis masuk ke sini** sebagai kategori "Bahan". Jadi pengeluaran selalu sinkron dengan aktivitas inventaris — tidak perlu double input.

Fitur:
- Lihat total pengeluaran hari ini di bagian atas
- Daftar semua catatan pengeluaran (terbaru di atas)
- Hapus catatan yang salah input

---

## 8. Laporan & Analitik

Ringkasan performa bisnis dalam satu halaman.

- Metrik omzet, laba, dan pengeluaran
- Grafik omzet 7 hari terakhir
- Daftar produk terlaris
- Alert bahan baku menipis

---

## 9. Riwayat Transaksi

Lihat detail 30 transaksi terakhir.

Setiap transaksi bisa di-expand untuk melihat:
- Daftar item yang dipesan (nama, kustomisasi, jumlah, subtotal)
- **Laba kotor transaksi tersebut**
- Tombol **Cetak Ulang** untuk mencetak kembali struk

> Laba kotor per item dihitung dari: `(Harga Jual + Surcharge − HPP) × Kuantitas`
> HPP yang dipakai adalah **snapshot saat transaksi terjadi**, sehingga laporan tetap akurat meski harga bahan berubah di kemudian hari.

---

## 10. Manajemen Menu

Kelola semua produk yang tersedia di kasir.

### Fitur Per Produk

| Fitur | Keterangan |
|---|---|
| **Toggle Tersedia** | Aktif/nonaktifkan produk di kasir secara instan tanpa hapus |
| **Edit Produk** | Ubah nama, harga, kategori, HPP manual, gambar, add-on |
| **Hapus Produk** | Menghapus produk dari daftar menu |

### Data yang Bisa Diatur per Produk

- Nama dan kategori (Kopi / Non Kopi / Makanan / Add-on)
- Harga jual
- HPP / modal (manual, bisa diganti oleh resep)
- Foto produk (dari galeri/file, maks. 5 MB)
- Default es dan gula
- **Add-on** eksklusif produk (nama + harga, bisa lebih dari satu) — khusus kategori Kopi

---

## 11. Printer & Struk

Aplikasi mendukung dua jenis printer:

| Jenis | Platform | Detail |
|---|---|---|
| **ESC/POS Thermal (Bluetooth)** | Android | Cetak struk langsung ke printer thermal portabel |
| **USB / Sistem** | Windows & Android | Termasuk cetak ke PDF ukuran 80mm |

### Isi Struk

- Nama & alamat toko
- Nomor transaksi & tanggal/jam
- Nama pembeli & metode pembayaran
- Daftar item (nama, kustomisasi, catatan, subtotal per baris)
- Subtotal · Diskon · Pajak · **Total**
- Pesan terima kasih

---

## 12. Reset Database

Tersedia di menu **More → Reset Database**.

> ⚠️ **Peringatan:** Tindakan ini akan menghapus **semua data** termasuk produk, transaksi, resep, pengeluaran, dan riwayat stok. Inventaris akan direset ke data awal bawaan. Tidak bisa dibatalkan.

---

## Catatan Teknis

| Aspek | Detail |
|---|---|
| **Platform** | Android & Windows |
| **Database** | SQLite lokal (tidak butuh internet) |
| **Keamanan data** | HPP di-snapshot saat transaksi, laporan historis tetap akurat |
| **Stok otomatis** | Terpotong saat transaksi berhasil, sesuai resep masing-masing produk |
| **Diskon & Pajak** | Belum aktif (saat ini Rp 0) |

---

*Kopi Kita POS — dibuat dengan Flutter*
