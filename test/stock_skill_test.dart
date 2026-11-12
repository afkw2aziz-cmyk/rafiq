import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_companion/skills/stock_skill.dart';

void main() {
  group('StockQuote.changePct', () {
    test('positive move', () {
      const q = StockQuote(
        symbol: 'AAPL',
        price: 110,
        prevClose: 100,
        name: 'Apple',
        currency: 'USD',
      );
      expect(q.changePct, closeTo(10, 0.0001));
    });

    test('negative move', () {
      const q = StockQuote(
        symbol: 'AAPL',
        price: 90,
        prevClose: 100,
        name: 'Apple',
        currency: 'USD',
      );
      expect(q.changePct, closeTo(-10, 0.0001));
    });

    test('zero previous close is safe', () {
      const q = StockQuote(
        symbol: 'X',
        price: 50,
        prevClose: 0,
        name: '',
        currency: '',
      );
      expect(q.changePct, 0);
    });
  });
}
