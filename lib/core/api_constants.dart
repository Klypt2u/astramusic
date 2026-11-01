/// Central InnerTube / YouTube Music networking constants.
///
/// All values here are *public client parameters* (the same ones every
/// open YouTube Music client uses). No user API keys are required.
library;

/// InnerTube API key for the WEB_REMIX (YouTube Music web) client.
const String kMusicInnertubeApiKey =
    'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';

/// InnerTube API key for the iOS (com.google.ios.youtube) client.
/// The iOS client returns *unscrambled* direct stream URLs, which is how
/// Astra gets playable audio without implementing signature deciphering.
const String kIosInnertubeApiKey =
    'AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc';

const String kMusicApiBase = 'https://music.youtube.com/youtubei/v1';
const String kYoutubeApiBase = 'https://www.youtube.com/youtubei/v1';

const String kMusicClientName = 'WEB_REMIX';
const String kMusicClientVersion = '1.20250210.01.00';
const String kMusicUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36';

const String kIosClientVersion = '19.45.4';
const String kIosUserAgent =
    'com.google.ios.youtube/$kIosClientVersion (iPhone16,2; U; CPU iOS 18_1 like Mac OS X)';
const String kIosDeviceModel = 'iPhone16,2';

Map<String, dynamic> get musicContext => {
      'client': {
        'clientName': kMusicClientName,
        'clientVersion': kMusicClientVersion,
        'hl': 'en',
        'gl': 'US',
        'originalUrl': 'https://music.youtube.com/',
        'userAgent': kMusicUserAgent,
      },
      'user': {'lockedSafetyMode': false},
    };

Map<String, dynamic> get iosPlayerContext => {
      'client': {
        'clientName': 'IOS',
        'clientVersion': kIosClientVersion,
        'deviceModel': kIosDeviceModel,
        'osName': 'iPhone',
        'osVersion': '18.1.0.22B83',
        'hl': 'en',
        'gl': 'US',
      },
    };

/// Browse IDs for the music home and charts tabs.
const String kBrowseHome = 'FEmusic_home';
const String kBrowseCharts = 'FEmusic_charts';

/// Search filter params for the InnerTube search endpoint.
/// Computed protobuf "params" for `scope: none, ignoreSpelling: false`,
/// matching the values ytmusicapi computes.
const Map<String, String> kSearchFilterParams = {
  'songs': 'EgWKAQIIAWoMEA4QChADEAQQCRAF',
  'videos': 'EgWKAQIQAWoMEA4QChADEAQQCRAF',
  'albums': 'EgWKAQIYAWoMEA4QChADEAQQCRAF',
  'artists': 'EgWKAQIgAWoMEA4QChADEAQQCRAF',
  'playlists': 'EgeKAQQoADgBagwQDhAKEAMQBBAJEAU%3D',
};

/// Browse-ID prefixes → result type (used to classify generic shelf items).
const Map<String, String> kBrowseIdPrefixTypes = {
  'VM': 'playlist',
  'RD': 'playlist',
  'VL': 'playlist',
  'MPLA': 'artist',
  'MPRE': 'album',
  'MPSP': 'podcast',
  'MPED': 'episode',
  'UC': 'artist',
};

/// Public Piped instances used as a fallback stream resolver when the
/// InnerTube iOS client fails (rate limits, region blocks, etc.).
const List<String> kPipedInstances = [
  'https://pipedapi.kavin.rocks',
  'https://pipedapi.adminforge.de',
  'https://api.piped.private.coffee',
  'https://pipedapi.ducks.party',
];

/// Public Invidious instances — second-line fallback.
const List<String> kInvidiousInstances = [
  'https://inv.nadeko.net',
  'https://invidious.nerdvpn.de',
];

/// Default thumbnail helper — YT serves these sizes directly per video ID.
String ytThumb(String videoId, {String size = 'mqdefault'}) =>
    'https://i.ytimg.com/vi/$videoId/$size.jpg';
