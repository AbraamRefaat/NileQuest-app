import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nile_quest/models/feedback.dart';
import 'package:nile_quest/services/feedback_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

StopFeedback _stopFeedback({String poiId = 'poi_1'}) => StopFeedback(
      poiId: poiId,
      poiName: 'Pyramids',
      category: 'Historical',
      rating: 5,
      tripSessionId: 'session_1',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = FeedbackService();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    service.httpClient = http.Client();
  });

  test('failed delivery queues the feedback instead of throwing', () async {
    service.httpClient = MockClient((_) async => http.Response('down', 503));

    await service.submitStopFeedback(_stopFeedback());

    expect(await service.pendingCount(), 1);
  });

  test('successful delivery does not queue', () async {
    service.httpClient = MockClient((_) async => http.Response('{}', 201));

    await service.submitStopFeedback(_stopFeedback());

    expect(await service.pendingCount(), 0);
  });

  test('queue flushes once the endpoint comes back', () async {
    service.httpClient = MockClient((_) async => http.Response('down', 503));
    await service.submitStopFeedback(_stopFeedback(poiId: 'a'));
    await service.submitStopFeedback(_stopFeedback(poiId: 'b'));
    expect(await service.pendingCount(), 2);

    var delivered = 0;
    service.httpClient = MockClient((request) async {
      delivered++;
      return http.Response('{}', 201);
    });

    await service.submitTripFeedback(TripFeedback(
      tripSessionId: 'session_1',
      overallRating: 4,
      wouldRecommend: true,
      stopsCompleted: 3,
      stopsPlanned: 4,
      distanceKm: 5.2,
    ));

    expect(await service.pendingCount(), 0);
    expect(delivered, 3, reason: '2 queued + 1 new');
  });

  test('queue is capped at 50, dropping oldest', () async {
    service.httpClient = MockClient((_) async => http.Response('down', 503));
    for (var i = 0; i < 55; i++) {
      await service.submitStopFeedback(_stopFeedback(poiId: 'poi_$i'));
    }
    expect(await service.pendingCount(), 50);
  });

  test('exceptions during POST are swallowed and queued', () async {
    service.httpClient = MockClient((_) async => throw Exception('no network'));

    await service.submitStopFeedback(_stopFeedback());

    expect(await service.pendingCount(), 1);
  });
}
