/// Map links that open in Google Maps / OpenStreetMap (no maps SDK or API
/// key needed).
Uri googleMapsUri(double lat, double lng) =>
    Uri.parse('https://www.google.com/maps/search/?api=1&query=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}');

Uri osmUri(double lat, double lng) => Uri.parse(
    'https://www.openstreetmap.org/?mlat=${lat.toStringAsFixed(6)}&mlon=${lng.toStringAsFixed(6)}#map=16/${lat.toStringAsFixed(6)}/${lng.toStringAsFixed(6)}');
