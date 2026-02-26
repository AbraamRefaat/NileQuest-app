/// Server configuration for Tazkarti API
/// Update productionUrl after deploying to Vercel

class TazkartiServerConfig {
  // Production URL - Update this with your Vercel URL after deployment
  // Example: https://tazkarti-backend.vercel.app
  static const String productionUrl = 'https://tazkarti-backend.vercel.app';

  /// Get the API URL
  static String getApiUrl() {
    return productionUrl;
  }

  /// Endpoint paths
  static const String musicEventsPath = '/api/events/music';

  /// Get full URL for music events endpoint
  static String getMusicEventsUrl() {
    return '$productionUrl$musicEventsPath';
  }
}
