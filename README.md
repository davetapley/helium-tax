# helium-tax
Calculate Helium hotspot USD income (useful for taxes)

This was written to sit behind a [Pipedream](https://pipedream.com/@davetapley/p_gYCMpx9/edit) trigger,
but you can run it straight on node if you:
1. Remove references to `event.url`
1. Provide your own hotspot `address`
1. Replace the `$respond` with a `console.log`