-- FAPI part numbers base: the table every brand file loads into.
-- One file for MySQL, MariaDB and PostgreSQL.

CREATE TABLE product_list (
    mfd character varying(255) NOT NULL,
    ns character varying(105) NOT NULL,
    n character varying(255),
    d character varying(255) NOT NULL,
    tp integer NOT NULL,
    upd bigint DEFAULT 0 NOT NULL
);

CREATE INDEX k_product_list_mfd_ns ON product_list (mfd, ns);
CREATE INDEX k_product_list_ns ON product_list (ns);
