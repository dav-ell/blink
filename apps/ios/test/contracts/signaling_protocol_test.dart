import 'package:flutter_test/flutter_test.dart';
import '../helpers/fixtures.dart';

/// These tests verify the WebRTC signaling message formats.
/// Update these if the signaling protocol changes.
void main() {
  group('WebRTC signaling protocol', () {
    group('offer message', () {
      test('offer message format', () {
        final message = makeOfferMessage('v=0\r\no=- 12345...');

        expect(message, {
          'type': 'offer',
          'sdp': 'v=0\r\no=- 12345...',
        });
      });

      test('offer requires type and sdp', () {
        final message = makeOfferMessage('test-sdp');
        
        expect(message.containsKey('type'), isTrue);
        expect(message.containsKey('sdp'), isTrue);
      });

      test('sdp is string', () {
        final message = makeOfferMessage('some-sdp-content');
        
        expect(message['sdp'], isA<String>());
      });
    });

    group('answer message', () {
      test('answer message format', () {
        final message = makeAnswerMessage('v=0\r\no=- 67890...');

        expect(message, {
          'type': 'answer',
          'sdp': 'v=0\r\no=- 67890...',
        });
      });

      test('answer type is "answer"', () {
        final message = makeAnswerMessage('sdp-content');
        
        expect(message['type'], 'answer');
      });
    });

    group('ICE candidate message', () {
      test('ICE candidate message format', () {
        final message = makeIceCandidateMessage(
          candidate: 'candidate:1 1 UDP 2122252543...',
          sdpMid: 'audio',
          sdpMLineIndex: 0,
        );

        expect(message, {
          'type': 'ice',
          'candidate': {
            'candidate': 'candidate:1 1 UDP 2122252543...',
            'sdpMid': 'audio',
            'sdpMLineIndex': 0,
          },
        });
      });

      test('candidate is nested object', () {
        final message = makeIceCandidateMessage(
          candidate: 'test-candidate',
          sdpMid: 'video',
          sdpMLineIndex: 1,
        );

        expect(message['candidate'], isA<Map>());
        expect(message['candidate']['candidate'], 'test-candidate');
        expect(message['candidate']['sdpMid'], 'video');
        expect(message['candidate']['sdpMLineIndex'], 1);
      });

      test('sdpMid can be null', () {
        final message = makeIceCandidateMessage(
          candidate: 'test',
          sdpMid: null,
          sdpMLineIndex: 0,
        );

        expect(message['candidate']['sdpMid'], isNull);
      });

      test('sdpMLineIndex can be null', () {
        final message = makeIceCandidateMessage(
          candidate: 'test',
          sdpMid: 'audio',
          sdpMLineIndex: null,
        );

        expect(message['candidate']['sdpMLineIndex'], isNull);
      });
    });
  });
}

