# India Post PIN Directory Import

## Authoritative source

Use a dated CSV snapshot from the Department of Posts' **All India Pincode Directory** published through the Government of India Open Government Data (OGD) portal:

- Resource: https://data.gov.in/resource/all-india-pincode-directory-till-last-month
- Catalog: https://data.gov.in/catalog/all-india-pincode-directory-through-webservice

Do not use an unofficial mirror as the production source. Record the source date and exact source title with every import. The OGD API-details page has reported that an API endpoint does not exist; use the official downloadable resource only when it is available and verify the file before import.

## CSV field mapping

Normalize the OGD column headings into the JSON field names accepted by the Admin import RPC:

| OGD field | RPC JSON field |
| --- | --- |
| `circlename` | `circle_name` |
| `regionname` | `region_name` |
| `divisionname` | `division_name` |
| `officename` | `office_name` |
| `pincode` | `pincode` |
| `officetype` | `office_type` |
| `delivery` | `delivery_status` |
| `district` | `district_name` |
| `statename` | `state_name` |

Each JSON row must have a six-digit PIN, office name, district name and state name. Preserve each post-office row; one PIN may have multiple offices and may be associated with more than one district.

## Admin-only RPC sequence

1. Call `srk_admin_begin_india_post_office_import` with the source date, exact number of distinct CSV rows, and source name. The expected row count must be at least 5,000.
2. Upload normalized rows using `srk_admin_import_india_post_office_chunk` in batches of 1–500 rows. Keep the returned batch ID.
3. Use `srk_admin_get_india_post_office_import_status` to inspect imported row count and batch state.
4. Call `srk_admin_list_unmapped_india_post_office_districts`. For every source district name that does not normalize to an active LGD district, map it with `srk_admin_map_india_post_office_district_alias`. The target LGD district must be active and in the same state; the mapping reason must be at least 10 characters.
5. Call `srk_admin_finalize_india_post_office_import`. Finalization requires the exact row count, 36 States/UTs, at least 500 district/state pairs, at least 5,000 distinct PINs and zero unmapped district names. It atomically replaces the live directory and enables server-side validation.
6. If the batch is wrong or cannot be completed, call `srk_admin_abort_india_post_office_import` with a reason of at least 10 characters. Do not start another batch while one is still importing.

## Safety behavior

- The import, staging and alias tables have RLS enabled and direct client table access revoked.
- Admin RPCs verify `public.is_srk_admin()`.
- Customer location validation compares the entered PIN with the selected official LGD district.
- The booking trigger remains inactive until an Admin finalizes a complete official directory. This prevents a missing/unimported dataset from blocking existing bookings.
- Never activate the directory using a partial file or a guessed row count.
