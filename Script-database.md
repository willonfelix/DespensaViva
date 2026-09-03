# Script do Banco de Dados — DespensaViva

> **ATUALIZADO (03/09/2026):** reflete o modelo **multi-tenant por Ambientes**.
> Este conteúdo é o mesmo de `backend/db/schema.sql` (fonte da verdade).
> O script original single-user (`user_id`) ficou ao final como histórico.

## Modelo atual (multi-tenant)

```sql
-- DespensaViva - Dispensa
-- Modelo com AMBIENTES (Dispensas) compartilháveis entre usuários.

-- Extensão para geração de UUIDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Tabela de Usuários
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(150),
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Tabela de Categorias
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE
);

-- 3. Tabela de Produtos (Catálogo Geral, compartilhado)
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    category_id INT REFERENCES categories(id) ON DELETE SET NULL,
    unit_of_measure VARCHAR(20) NOT NULL DEFAULT 'unidade',
    UNIQUE (name, unit_of_measure)
);

-- 4. Tabela de Ambientes (Dispensas)
CREATE TABLE environments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(150) NOT NULL,
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. Tabela de Membros do Ambiente
CREATE TABLE environment_members (
    environment_id UUID NOT NULL REFERENCES environments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL DEFAULT 'member',  -- 'owner' | 'member'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (environment_id, user_id)
);

-- 6. Tabela de Itens da Dispensa (Estoque do Ambiente)
CREATE TABLE pantry_items (
    id SERIAL PRIMARY KEY,
    environment_id UUID NOT NULL REFERENCES environments(id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity DECIMAL(10, 2) NOT NULL DEFAULT 0,
    min_quantity DECIMAL(10, 2) NOT NULL DEFAULT 0,
    expiration_date DATE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (environment_id, product_id)
);

-- 7. Tabela de Lista de Compras (do Ambiente)
CREATE TABLE shopping_list (
    id SERIAL PRIMARY KEY,
    environment_id UUID NOT NULL REFERENCES environments(id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity DECIMAL(10, 2) NOT NULL DEFAULT 1,
    is_checked BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (environment_id, product_id, is_checked)
);

-- Índices para consultas frequentes
CREATE INDEX idx_env_members_user ON environment_members(user_id);
CREATE INDEX idx_pantry_environment ON pantry_items(environment_id);
CREATE INDEX idx_pantry_product ON pantry_items(product_id);
CREATE INDEX idx_pantry_expiration ON pantry_items(environment_id, expiration_date);
CREATE INDEX idx_shopping_environment ON shopping_list(environment_id);
CREATE INDEX idx_shopping_environment_pending ON shopping_list(environment_id, is_checked);

-- Trigger para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_pantry_updated_at ON pantry_items;
CREATE TRIGGER trg_pantry_updated_at
BEFORE UPDATE ON pantry_items
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Categorias iniciais comuns
INSERT INTO categories (name) VALUES
('Grãos e Cereais'),
('Mercearia e Temperos'),
('Laticínios'),
('Limpeza'),
('Bebidas'),
('Hortifrúti'),
('Congelados'),
('Carnes');
```

---

## Histórico — Script original (single-user, DESATUALIZADO)
O modelo abaixo foi o primeiro plano (itens atrelados a `user_id`) e foi **substituído** pelo multi-tenant (itens por `environment_id`). Mantido apenas como registro.

```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE
);
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    category_id INT REFERENCES categories(id) ON DELETE SET NULL,
    unit_of_measure VARCHAR(20) NOT NULL
);
CREATE TABLE pantry_items (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    product_id INT REFERENCES products(id) ON DELETE CASCADE,
    quantity DECIMAL(10, 2) NOT NULL DEFAULT 0,
    min_quantity DECIMAL(10, 2) NOT NULL DEFAULT 0,
    expiration_date DATE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE shopping_list (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    product_id INT REFERENCES products(id) ON DELETE CASCADE,
    quantity DECIMAL(10, 2) NOT NULL DEFAULT 1,
    is_checked BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO categories (name) VALUES
('Grãos e Cereais'), ('Mercearia e Temperos'), ('Laticínios'),
('Limpeza'), ('Bebidas'), ('Hortifrúti');
```
