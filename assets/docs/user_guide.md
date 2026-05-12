# 📘 Docara POS User Guide

> **Docara POS** is a professional Point-of-Sale, invoice, and receipt management system designed for retail and service businesses.



## Table of Contents

1. [Getting Started](#1-getting-started)
2. [Logging In](#2-logging-in)
3. [Admin Dashboard](#3-admin-dashboard)
4. [Cashier Dashboard](#4-cashier-dashboard)
5. [Creating an Invoice](#5-creating-an-invoice)
6. [Creating a Receipt](#6-creating-a-receipt)
7. [Creating a POS (Point of Sale) Sale](#7-creating-a-pos-point-of-sale-sale)
8. [Viewing & Sharing Documents](#8-viewing--sharing-documents)
9. [Barcode Scanner](#9-barcode-scanner)
10. [Barcode Studio](#10-barcode-studio)
11. [Product Catalog (Inventory)](#11-product-catalog-inventory)
12. [Customer Management](#12-customer-management)
13. [Expense Tracking](#13-expense-tracking)
14. [Staff Management](#14-staff-management)
15. [Business Profile & Settings](#15-business-profile--settings)
16. [Role Permissions Summary](#16-role-permissions-summary)



## 1. Getting Started

### First-Time Setup
If you are opening Docara for the first time:

1. On the Login screen, tap **"New business? Create an account →"**
2. Enter your **business name**, **email address**, and a **password**
3. Tap **Create Account** you will be taken straight to your dashboard
4. Tap your **business name** at the top of the screen to open **Business Profile** and fill in your details (address, phone, currency, logo, etc.)

> [!TIP]
> Set up your **currency symbol**, **business address**, and **logo** first these appear on every invoice and receipt you generate.



## 2. Logging In

The login screen has two modes selectable at the top: **STAFF** and **ADMIN**.

### Admin Login
| Field | What to enter |
|:---|:---|
| **Mode** | Tap **ADMIN** |
| **Email** | Your registered business email |
| **Password** | Your account password |

• Tap **UNLOCK SYSTEM** to log in
• Forgot your password? Enter your email then tap **Forgot Password?** a reset link will be sent to your inbox

### Cashier (Staff) Login
| Field | What to enter |
|:---|:---|
| **Mode** | Tap **STAFF** |
| **Name** | Select your name from the dropdown list |
| **PIN** | Enter your 4-digit PIN |

• Tap **UNLOCK SYSTEM** to log in as a cashier
• Cashiers are added by the Admin: 	see [Staff Management](#14-staff-management)

> [!IMPORTANT]
> Staff accounts are created and managed entirely by the Admin. If your name does not appear in the dropdown, ask your Admin to add you.



## 3. Admin Dashboard

When logged in as Admin, you see the full dashboard with **5 tabs**:

| Tab | Icon | What it contains |
|:---|:---:|:---|
| **Dashboard** | 📊 | Revenue goal, totals, charts, low stock alerts, staff & station performance |
| **Documents** | 📄 | All invoices, receipts, and estimates across all cashiers |
| **Clients** | 👥 | Saved customer records |
| **Inventory** | 📦 | Product catalog and stock levels |
| **Expenses** | 💸 | Business expense records |

### Dashboard Cards
• **Revenue Goal card**: Shows your monthly revenue progress bar
• **Revenue / Net Profit / Expenses / Unpaid**: Four key business metrics at a glance
• **Revenue Trends**: A line chart of daily revenue for the current month
• **Low Stock Alerts**: Products below their minimum stock level
• **Staff Performance**: Revenue breakdown by each cashier
• **Station Performance**: Revenue breakdown by each registered device/station

### Quick Actions (Top-right of Profile Card)
| Button | Action |
|:---|:---|
| 📷 QR Scanner | Open Barcode Studio |
| 🧾 POS icon | Start a new POS sale immediately |

### Sync Button (Top App Bar)
• The **sync icon** (↻) opens Sync Settings where you can configure your cloud connection
• The **cloud-off icon** (☁️ red) appears when there are offline receipts waiting to be uploaded   tap it to sync them now



## 4. Cashier Dashboard

When logged in as a **Cashier**, you see a simplified view with **2 tabs**:

| Tab | What it shows |
|:---|:---|
| **Dashboard** | Your personal sales performance for today |
| **My Documents** | Only the invoices and receipts **you** created |

### What Cashiers Can Do
• ✅ Create new Invoices / Receipts
• ✅ Create new POS Sales
• ✅ Use the Barcode Scanner
• ✅ View their own documents and preview PDFs
• ❌ Cannot edit or delete any document
• ❌ Cannot see other cashiers' sales or business-wide revenue

### Cashier Floating Action Buttons
Three buttons appear at the bottom-right:
1. **Create Invoice/Receipt**   Opens the invoice editor
2. **New Sale (POS)**   Opens POS mode
3. **Barcode Scanner**   Scans a product barcode to start or add to a sale



## 5. Creating an Invoice

An **Invoice** is a formal billing document sent to a client for payment.

### Steps
1. From the **Documents** tab, tap **Create Invoice** (blue button, bottom-right)  
   *  or tap the floating "Create Invoice/Receipt" button if you are a cashier*
2. Set the **Document Mode** (toggles at the top):
   • **Receipt Mode** OFF = Invoice, ON = Receipt
   • **Estimate Mode** ON = saves as a Quote, not a final invoice
3. Fill in **Document Details**:
   • **Invoice Number**: Auto-generated; you can edit it
   • **Date**: Tap to pick a date *(Admin only can change dates)*
4. Fill in **Client Information**:
   • Type the client's name, address, and contact
   • Or tap the **👤+** icon to pick from saved customers
5. Add **Line Items**:
   • Tap **Add Item** to manually type a product name, quantity, and price
   • Tap **Catalog** to pick from your saved product inventory
   • Tap **Scan** to scan a product barcode with the camera
6. Review the **Summary Card** at the bottom (subtotal, tax, discount, total)
7. Tap **Preview PDF** to view the final document
8. From the preview, tap **Save & Share** or **Print**

> [!TIP]
> You can add a **discount** (percentage or fixed amount) and **tax rate** directly in the Summary Card.



## 6. Creating a Receipt

A **Receipt** confirms a completed payment.

### Steps
1. Follow the same steps as creating an Invoice
2. **Toggle "Receipt Mode" ON** using the switch in the Document Details section
3. The document type will automatically change to **RECEIPT**
4. Complete the client info and add items as normal
5. Preview, save, and share as needed



## 7. Creating a POS (Point of Sale) Sale

POS mode is optimized for fast checkout at a counter   ideal for walk-in retail customers.

### Steps
1. Tap the **"New Sale (POS)"** floating button  
   *  or tap the POS icon in the profile card header*
2. Enter the **Cashier Name** (auto-filled if you are logged in as a cashier)
3. Add items using any of these methods:
   • **Add Item**: type it manually
   • **Catalog**: choose from saved products
   • **Scan**: scan a barcode with the camera
   • **USB/Bluetooth hardware scanner**: just scan directly, items are detected automatically
4. Scroll down to see **POS Receipt Customization** options (receipt width, custom notes, etc.)
5. Tap **Preview PDF**   this generates a thermal-style receipt
6. Print or share the receipt

> [!NOTE]
> POS receipts use a compact thermal-printer format (80mm roll). You can print directly to a connected receipt printer from the preview screen.



## 8. Viewing & Sharing Documents

### From the Documents Tab (Admin) / My Documents Tab (Cashier)
Tap any document in the list to see options:

| Option | Who can use it |
|:---|:---|
| **View / Preview** | Everyone (Admin, Manager, Cashier) |
| **Edit Document** | Admin only |
| **Void / Refund** | Admin only (requires Manager PIN) |
| **Delete Document** | Admin only (requires Manager PIN) |

> [!IMPORTANT]
> Cashiers can **only view** documents they created. They cannot edit, void, or delete anything.

### From the PDF Preview Screen
Once a document is open:
• **Share**: sends the PDF via any installed app (WhatsApp, Email, etc.)
• **Print**: sends to a connected printer
• **Download**: saves the PDF locally



## 9. Barcode Scanner

The barcode scanner can be used in two places:

### During Invoice / POS Creation
• Tap **Scan** in the Items List header
• Point the camera at the product barcode
• If the product is in your catalog   it is added to the invoice automatically
• If not found   you are prompted to add a new product to the catalog *(Admin PIN required to save new products)*

### From the Inventory Tab (Product Scan)
• Tap **Scan** from the Inventory tab's floating buttons
• Scan a product to check if it exists in the catalog

### Hardware Scanner Support
If you have a **USB or Bluetooth barcode scanner**:
• Simply scan while the invoice editor is open   items are detected and added automatically without touching the screen

> [!TIP]
> Enable the **flashlight/torch** icon inside the scanner window if you are scanning in a dark environment.



## 10. Barcode Studio

Generate and print barcodes for your products.

### Opening Barcode Studio
• Tap the **QR/Barcode icon** (📷) in the top-right of the home screen profile card

### Using Barcode Studio
1. Choose a mode:
   • **Product Mode**: select an existing product from your catalog (must already have a barcode saved)
   • **Quick Mode**: enter a custom product name, price, and barcode data manually
2. Choose a **barcode format**:
   • Code 128 (most common, all characters)
   • QR Code (best for digital sharing)
   • EAN-13 (international retail   12-13 digits)
   • Code 39, UPC-A, Data Matrix
3. Tap **Auto-Generate** ⚡ to create a random barcode number (Quick Mode)
4. A live **preview** shows your barcode in real-time
5. Tap **Print Barcode** to send it to a printer



## 11. Product Catalog (Inventory)

### Adding a Product (Admin Only)
1. Go to the **Inventory** tab
2. Tap **Add Product** (bottom-right button)
3. Fill in:
   • **Product Name**
   • **Sell Price**: the price charged to customers
   • **Cost Price**: your purchase cost (used for profit calculation, hidden from cashiers)
   • **Current Stock**: how many units you have
   • **Minimum Stock Level**: you will get a low-stock alert below this number
   • **Barcode**: optional; scan or type a barcode ID
4. Tap **Save Product**

### Viewing & Editing Products
• Tap any product in the Inventory list to see options:
  • **View Barcode**: shows the product's barcode (if set)
  • **Edit Product**: modify details *(Admin only)*
  • **Delete Product** *(Admin only)*

> [!NOTE]
> Low-stock products are highlighted in red and also appear on the **Admin Dashboard** under "Low Stock Alerts".



## 12. Customer Management

### Adding a Customer
1. Go to the **Clients** tab
2. Tap **Add Customer** (bottom-right button)
3. Enter the customer's **Name**, **Address**, and **Contact** (phone or email)
4. Tap **SAVE**

### Using a Saved Customer in an Invoice
When creating an invoice, tap the **👤+** icon next to the Client Name field to pick a saved customer   their details are filled in automatically.

### Customer Records
• Each customer card shows:
• **Total Amount Spent**: sum of all their invoices
• **Number of Invoices**: how many documents they appear in

> [!NOTE]
> Customers can be edited by anyone, but only the **Admin** can delete a customer record.



## 13. Expense Tracking

Track your business costs separately from sales.

### Adding an Expense (Admin Only)
1. Go to the **Expenses** tab
2. Tap **Add Expense** (bottom-right button) you will be asked to enter the **Admin PIN**
3. Fill in:
   • **Description**: e.g., "Office Supplies"
   • **Amount**
   • **Category**: (e.g., Rent, Utilities, Stock, etc.)
   • **Date**
4. Tap **Save**

### Viewing Expenses
• All expenses are listed in the Expenses tab
• Each entry shows description, category, date, and amount
• Tap any expense to **Edit** or **Delete** it *(Admin only)*

> [!TIP]
> Expenses are factored into the **Net Profit** calculation shown on your Admin Dashboard: `Net Profit = Total Revenue - Total Expenses`.



## 14. Staff Management

Only the **Admin** can manage staff.

### Adding a Cashier
1. Tap your **cashier name / "Admin"** label on the home screen profile card  
   *  or go to the sync icon   Staff is accessible from the profile card*
2. Actually: tap the **underlined cashier name** in the profile card to open Staff Management
3. Tap **Add Staff Member** (blue button, bottom-right)
4. Fill in:
   • **Name**: Full name of the cashier
   • **Phone**: Optional
   • **Login PIN**: A unique 4-digit PIN the cashier will use to log in
   • **Role**: Cashier / Manager / Sales Associate
5. Tap **SAVE STAFF**

### Activating a Cashier Session
• In the Staff Management screen, tap **ACTIVATE** next to a staff member's name
• The home screen will switch to Cashier Mode for that person
• To return to Admin mode, tap **RESET TO ADMIN** at the top of Staff Management

### Editing or Removing Staff
• Tap any staff card   edit icon (✏️) to modify
• Tap the delete icon (🗑️) to remove a cashier

> [!WARNING]
> Deleting a staff member does **not** delete their past sales records   all historical documents remain. You simply can't select them for future transactions.

> [!CAUTION]
> Each PIN must be **unique**. The app will prevent you from saving a PIN that is already used by another staff member.



## 15. Business Profile & Settings

### Opening Business Profile
Tap your **business logo** or **business name** in the top profile card (Admin only).

### What You Can Configure
| Setting | Description |
|:---|:---|
| **Business Name** | Appears on all invoices and receipts |
| **Address** | Printed below the business name |
| **Phone / Email** | Contact info on documents |
| **Logo** | Upload your company logo |
| **Currency Symbol** | e.g., ₵, $, £, ₦ |
| **Revenue Goal** | Monthly target shown on the dashboard |
| **Manager PIN** | PIN required to authorize sensitive actions |
| **Station Name** | Identifies this device (e.g., "Counter 1") |
| **Invoice Template** | Choose your PDF layout style |

> [!IMPORTANT]
> The **Manager PIN** is separate from cashier PINs. It is used to approve destructive admin actions even when a cashier is logged in. Keep it confidential.



## 16. Role Permissions Summary

| Feature | Admin | Manager | Sales Assoc | Cashier |
|:---|:---:|:---:|:---:|:---:|
| **View own documents** | ✅ | ✅ | ✅ | ✅ |
| **View all documents** | ✅ | ✅ | ❌ | ❌ |
| **Create Invoice / Receipt** | ✅ | ✅ | ✅ | ✅ |
| **Create POS Sale** | ✅ | ✅ | ✅ | ✅ |
| **Edit a document** | ✅ | ❌ | ❌ | ❌ |
| **Delete / Void** | ✅ | ❌ | ❌ | ❌ |
| **Add / Edit Products** | ✅ | ✅ | ❌ | ❌ |
| **Add / Edit Customers** | ✅ | ✅ | ❌ | ❌ |
| **Delete Products/Clients** | ✅ | ❌ | ❌ | ❌ |
| **Track Expenses** | ✅ | ❌ | ❌ | ❌ |
| **Manage Staff** | ✅ | ❌ | ❌ | ❌ |
| **Edit Business Profile** | ✅ | ❌ | ❌ | ❌ |
| **Change Invoice Dates** | ✅ | ❌ | ❌ | ❌ |
| **View Revenue / Profits** | ✅ | ❌ | ❌ | ❌ |
| **View Low Stock Alerts** | ✅ | ✅ | ❌ | ❌ |
| **Access Sync Settings** | ✅ | ❌ | ❌ | ❌ |



*Docara POS   Built for growing businesses. For support, contact your system administrator.*
