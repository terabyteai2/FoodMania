// Per-template component overrides for the Sultan's Hearth slug.
// Other themes don't have an entry in THEME_OVERRIDES and continue
// rendering the default shared screens from App.jsx.

import HearthStorefront from './HearthStorefront.jsx'
import HearthItemSheet from './HearthItemSheet.jsx'
import HearthCart from './HearthCart.jsx'
import HearthSuccess from './HearthSuccess.jsx'
import HearthLoading from './HearthLoading.jsx'
import HearthError from './HearthError.jsx'

const sultansHearthOverrides = {
  Storefront: HearthStorefront,
  ItemSheet:  HearthItemSheet,
  Cart:       HearthCart,
  Success:    HearthSuccess,
  Loading:    HearthLoading,
  Error:      HearthError,
}

export default sultansHearthOverrides
