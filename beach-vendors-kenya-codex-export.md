# Beach Vendors Kenya -- Full Technical Export (Codex Ready)

## Project Goal

Build a PHP + MySQL online shop for beach vendors in Kenya with:

-   Multi-Currency (KES / EUR / USD)
-   Admin login & dashboard
-   Online product management (CRUD)
-   Image upload into dedicated folder (/uploads/shoes/)
-   Shopping cart + checkout
-   Order management
-   Separated database configuration (local vs hosting)

------------------------------------------------------------------------

# 1. Project Structure

public_html/ │ ├── index.php ├── product.php ├── cart.php ├──
checkout.php ├── login.php ├── logout.php ├── setup.php │ ├── admin/ │
├── index.php │ ├── products.php │ └── orders.php │ ├── includes/ │ ├──
config.php │ ├── db.php │ ├── db_config.php │ ├── db_config.local.php │
├── db_config.hosting.php │ ├── auth.php │ └── functions.php │ ├──
assets/ │ └── style.css │ └── uploads/ └── shoes/

------------------------------------------------------------------------

# 2. Database Schema (MySQL)

CREATE TABLE users ( id INT AUTO_INCREMENT PRIMARY KEY, name
VARCHAR(120) NOT NULL, phone VARCHAR(40), password_hash VARCHAR(255) NOT
NULL, role ENUM('admin','seller') NOT NULL DEFAULT 'seller', created_at
TIMESTAMP DEFAULT CURRENT_TIMESTAMP );

CREATE TABLE products ( id INT AUTO_INCREMENT PRIMARY KEY, user_id INT
NOT NULL, title VARCHAR(160) NOT NULL, description TEXT, price_kes
DECIMAL(10,2) NOT NULL, stock INT DEFAULT 0, image_path VARCHAR(255),
active TINYINT(1) DEFAULT 1, created_at TIMESTAMP DEFAULT
CURRENT_TIMESTAMP, FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE
CASCADE );

CREATE TABLE orders ( id INT AUTO_INCREMENT PRIMARY KEY, customer_name
VARCHAR(160) NOT NULL, customer_phone VARCHAR(60) NOT NULL,
delivery_area VARCHAR(160), notes TEXT, currency ENUM('KES','EUR','USD')
DEFAULT 'KES', fx_rate DECIMAL(12,6) DEFAULT 1.0, status
ENUM('new','confirmed','fulfilled','cancelled') DEFAULT 'new',
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP );

CREATE TABLE order_items ( id INT AUTO_INCREMENT PRIMARY KEY, order_id
INT NOT NULL, product_id INT NOT NULL, qty INT NOT NULL, unit_price_kes
DECIMAL(10,2) NOT NULL, FOREIGN KEY (order_id) REFERENCES orders(id) ON
DELETE CASCADE, FOREIGN KEY (product_id) REFERENCES products(id) ON
DELETE RESTRICT );

------------------------------------------------------------------------

# 3. Configuration Separation

## db_config.php

Active DB credentials file.

Local development: - Copy db_config.local.php → db_config.php

Hosting: - Copy db_config.hosting.php → db_config.php

## config.php

Contains: - FX exchange rates - Upload settings - Site name

Example:

return \[ 'fx' =\> \[ 'KES' =\> 1.0, 'EUR' =\> 0.0061, 'USD' =\> 0.0068,
\], 'upload' =\> \[ 'dir' =\> **DIR** . '/../uploads/shoes/',
'max_bytes' =\> 2500000, 'allowed_mime' =\>
\['image/jpeg','image/png','image/webp'\], \],\];

------------------------------------------------------------------------

# 4. Image Upload System

Images stored physically in:

public_html/uploads/shoes/

Public URL:

/uploads/shoes/filename.jpg

Folder permissions: - uploads → 755 - uploads/shoes → 755 (or 775 if
required)

------------------------------------------------------------------------

# 5. Admin System

Login: /login.php Dashboard: /admin/index.php Product Management:
/admin/products.php Orders: /admin/orders.php

Setup file: - /setup.php creates first admin - Must be deleted after use

------------------------------------------------------------------------

# 6. Multi-Currency Logic

Base currency: KES Display currency converted via fixed FX rate in
config.php

Orders store: - Selected currency - FX rate at time of purchase - Prices
in KES

------------------------------------------------------------------------

# 7. Current Status

-   Fully functional locally
-   Functional on hosting
-   Online product CRUD
-   Separate image folder
-   Database config separated

------------------------------------------------------------------------

# 8. Suggested Next Enhancements

-   Product categories
-   Shoe sizes with per-size inventory
-   Multi-seller login system
-   Revenue dashboard
-   M-Pesa integration
-   WhatsApp auto-order message
-   SEO optimization
-   REST API version

------------------------------------------------------------------------

END OF EXPORT
