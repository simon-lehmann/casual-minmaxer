# Client DB2 tables

CSV exports of the live TBC Classic client, fetched from wago.tools:

- https://wago.tools/db2/ItemRandomSuffix/csv?build=2.5.6.69795
- https://wago.tools/db2/ItemRandomProperties/csv?build=2.5.6.69795
- https://wago.tools/db2/SpellItemEnchantment/csv?build=2.5.6.69795
- https://wago.tools/db2/RandPropPoints/csv?build=2.5.6.69795

Build: 2.5.6.69795

They drive random-suffix greens ("of the Bear"), vanilla random properties ("of the Monkey") and
socket bonus values. Refresh with `scripts/fetch-dbc.sh [build]`. The CMaNGOS snapshot supplies
which suffix pool each item rolls (item_enchantment_template); these tables supply what each
suffix grants and how it scales with item level.
