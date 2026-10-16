# FAPI auto parts: sample part numbers by brand

This repository contains a sample of the FAPI part numbers base: 100 part numbers with part names per brand for 2,641 brands, one file per brand. `brands.csv` lists 11,010 brands of the base with their full-base and sample counts. A schema and load commands for MySQL, MariaDB and PostgreSQL are included.

Developers and data engineers can load and query the sample to evaluate data for parts shop product cards and accounting system item lists. It includes OE and aftermarket numbers with Russian part names. The sample is for evaluation only.

## Files

| File | What it holds |
|---|---|
| `scheme.sql` | the table and its indexes; one file for all three servers |
| `brands.csv` | the brands of the base, each with its number of part numbers in the full base and in this sample, and the path of its file |
| `brands/<X>/<BRAND>.tsv` | 100 part numbers of one brand |

### The brand files

- UTF-8 with a byte-order mark; lines end with CR LF; fields are separated by a TAB.
- The first row names the six columns: `mfd`, `ns`, `n`, `d`, `tp`, `upd`. Every other row is
  one part number.
- There is no quoting: whatever stands between two TABs is the value. No value holds a TAB or a
  line break, and no value is empty.
- Rows are sorted by `ns`.
- A file is named after the brand's normalised name: upper case, letters and digits. Anything
  a file system might refuse becomes `_`. `<X>` is the first character of that name, so no
  directory holds more than a few hundred files.
- Some brands are Russian and are named in Cyrillic, and so are their files and directories.

### `brands.csv`

UTF-8 with a byte-order mark, lines end with CR LF, values are separated by commas; a value
that holds a comma or a quote is quoted, as RFC 4180 has it.

| Column | Meaning |
|---|---|
| `mfd` | the brand, as its rows write it |
| `articles_total` | its part numbers in the full base |
| `articles_in_sample` | its part numbers in this sample: `100`, or `0` when fewer than 100 of them have a name |
| `sample_file` | the path of its file; empty when the brand is not in the sample |

## What the sample covers

| | |
|---|---|
| Brands in the sample | 2 641 |
| Rows in the sample | 264 100 |
| Brands in `brands.csv` | 11 010 |
| Part numbers of those brands | 41 393 670 |
| Brands left out of the sample | 8 369 |

A brand is in the sample only when at least 100 of its part numbers have a name: one with at least
one letter in it, and not a placeholder word such as "part". Of those, the 100 updated last are
taken. One load gives many part numbers the same update time; among those, the
pick follows a fixed hash of the number, so the 100 spread over the whole load. The sample is
the same every time it is produced from the same data. A brand with fewer named part numbers
has no file, but `brands.csv` still lists it with its count.

## Join the brand files

The whole sample loads from one file: the brand files joined without their header rows. In a
shell on Linux or macOS (on Windows: Git Bash or WSL), from the directory that holds this README:

```
tail -q -n +2 brands/*/*.tsv > all-brands.tsv
```

## Load into MySQL or MariaDB

Start the client with local files allowed and UTF-8 on the connection, from the directory that
holds the files:

```
mysql --local-infile=1 --default-character-set=utf8mb4 -u <user> -p
```

```
CREATE DATABASE fapi_parts CHARACTER SET utf8mb4;
USE fapi_parts;
SOURCE scheme.sql;
LOAD DATA LOCAL INFILE 'all-brands.tsv' INTO TABLE product_list CHARACTER SET utf8mb4 FIELDS TERMINATED BY '\t' ESCAPED BY '' LINES TERMINATED BY '\r\n' (mfd, ns, n, d, tp, upd);
```

One brand, straight from its file — `IGNORE 1 LINES` skips the header row:

```
LOAD DATA LOCAL INFILE 'brands/B/BOSCH.tsv' INTO TABLE product_list CHARACTER SET utf8mb4 FIELDS TERMINATED BY '\t' ESCAPED BY '' LINES TERMINATED BY '\r\n' IGNORE 1 LINES (mfd, ns, n, d, tp, upd);
```

- The server has to allow local files as well. MySQL 8.4 ships with that switched off, and the
  load is refused until an administrator runs `SET GLOBAL local_infile = 1;`. MariaDB allows it
  out of the box.
- `ESCAPED BY ''` makes a backslash inside a value plain data.
- `--default-character-set=utf8mb4` keeps the client on UTF-8 whatever the locale of the
  machine. A client that finds no UTF-8 locale falls back to latin1: the Russian names then
  print as `?`, and a query with a Russian word finds nothing. The load itself is safe either
  way, since `CHARACTER SET utf8mb4` names the encoding of the file.

## Load into PostgreSQL

Start `psql` from the directory that holds the files:

```
psql -U <user> -d postgres
```

```
CREATE DATABASE fapi_parts;
\c fapi_parts
\i scheme.sql
\copy product_list (mfd, ns, n, d, tp, upd) FROM 'all-brands.tsv' WITH (FORMAT csv, DELIMITER E'\t', QUOTE E'\x01', ENCODING 'UTF8')
```

One brand, straight from its file — `HEADER true` skips the header row:

```
\copy product_list (mfd, ns, n, d, tp, upd) FROM 'brands/B/BOSCH.tsv' WITH (FORMAT csv, DELIMITER E'\t', QUOTE E'\x01', HEADER true, ENCODING 'UTF8')
```

- Each `\copy` is one line.
- The files have no quoting, so the commands name a quote character that never occurs in them:
  a `"` or a backslash inside a value stays what it is. The default text format would read a
  backslash as an escape.

## Example queries

Numbers are searched by their normalised form, the column `ns`: lower case, letters and digits
only. `6PK1220`, `6PK 1220` and `6pk-1220` are all `6pk1220`.

The part numbers of one brand:

```sql
SELECT ns, n, d, tp, upd
FROM product_list
WHERE mfd = 'BOSCH'
ORDER BY ns;
```

One number across brands — here a ribbed belt that many brands make:

```sql
SELECT mfd, n, d
FROM product_list
WHERE ns = '6pk1220'
ORDER BY mfd;
```

Part numbers by a word of their name — the names are in Russian; this one finds spark plugs:

```sql
SELECT mfd, n, d
FROM product_list
WHERE LOWER(d) LIKE '%свеча зажигания%'
ORDER BY mfd, ns;
```

## Field reference

`product_list` — a part number of a brand:

| Column | Meaning |
|---|---|
| `mfd` | the brand |
| `ns` | the number normalised for search: lower case, letters and digits only; one row per brand and `ns` |
| `n` | the number as its maker writes it, with spaces, dots and dashes; `not_set` when the spelling is not known, and `ns` is the one to show then |
| `d` | what the part is: its name, in Russian for nearly every row |
| `tp` | `50` a number from the brand's own catalogue, `10` an original (OE) number, `-1` not stated; `0`, `1` and `30` have no defined meaning, treat them as not stated |
| `upd` | last update, Unix time in milliseconds; `0` when not known |

## Tested on

| Server | Version | Client |
|---|---|---|
| MySQL | 8.4.11 | `mysql` 8.4.11 |
| MariaDB | 11.8.9 | `mariadb` 15.2, the one shipped with the server |
| PostgreSQL | 18.6 | `psql` 18.6 |

On each of them the schema was created, and the joined file and one brand file were loaded with
the commands above. Every row of the brand files went in, the table read back equal to the
files byte for byte, and the three queries gave the same rows on all three servers.

## Licence

The schema and the load commands are under the MIT License (`LICENSE`). The sample data is for evaluation only (`DATA-LICENSE.md`). You may download it, load it and query it to evaluate the format and the data. You may not redistribute it, publish it elsewhere or use it in a product or a service.

## Full dataset

The FAPI part numbers base contains more than 41.3 million OE and aftermarket part numbers across more than 11,000 brands, measured on 2026-10-16. It comes as text in one or several files, or as an SQL file for MySQL and PostgreSQL. This repository’s brand files show the full base’s layout with an added header row. Get the full base from the [product page (in Russian)](https://fapi.iisis.ru/baza-artikulov-avtozapchastej?utm_source=github&utm_medium=readme&utm_campaign=auto-part-numbers).
