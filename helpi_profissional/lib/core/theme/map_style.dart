// =============================================================
// HELPI Profissional — Estilo Dark Premium para o Google Maps
//
// ⚠️ REGRAS DE OURO PARA NÃO CAUSAR TELA PRETA:
//   1. Nunca usar "color" sem "weight" num elemento de geometria.
//   2. Nunca setar visibility: "off" no elemento "geometry" da
//      camada "landscape" ou "water" — isso apaga os tiles.
//   3. Não usar lightness: -100 em "geometry.fill" do landscape.
// =============================================================

const String kMapStyleDarkPremium = '''
[
  {
    "elementType": "geometry",
    "stylers": [{ "color": "#1a1a2e" }]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [{ "color": "#1a1a2e" }]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#8892b0" }]
  },
  {
    "featureType": "administrative.locality",
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#ccd6f6" }]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#64ffda" }]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [{ "color": "#0d2137" }]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#3d7a5e" }]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [{ "color": "#16213e" }]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [{ "color": "#212a37" }]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#9ca5b3" }]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [{ "color": "#0f3460" }]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [{ "color": "#1a1a4e" }]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#e94560" }]
  },
  {
    "featureType": "transit",
    "elementType": "geometry",
    "stylers": [{ "color": "#0d1b2a" }]
  },
  {
    "featureType": "transit.station",
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#64ffda" }]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{ "color": "#0d1b2a" }]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#4e6d88" }]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.stroke",
    "stylers": [{ "color": "#17263c" }]
  }
]
''';
