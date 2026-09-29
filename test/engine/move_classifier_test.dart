import 'package:flutter_test/flutter_test.dart';
import 'package:karpachess/engine/domain/engine_models.dart';
import 'package:karpachess/engine/domain/move_classifier.dart';

void main() {
  group('MoveClassifier.classify — exact web thresholds', () {
    test('boundaries', () {
      expect(MoveClassifier.classify(0), MoveQuality.best);
      expect(MoveClassifier.classify(19), MoveQuality.best);
      expect(MoveClassifier.classify(20), MoveQuality.good);
      expect(MoveClassifier.classify(59), MoveQuality.good);
      expect(MoveClassifier.classify(60), MoveQuality.inaccuracy);
      expect(MoveClassifier.classify(149), MoveQuality.inaccuracy);
      expect(MoveClassifier.classify(150), MoveQuality.mistake);
      expect(MoveClassifier.classify(299), MoveQuality.mistake);
      expect(MoveClassifier.classify(300), MoveQuality.blunder);
      expect(MoveClassifier.classify(2500), MoveQuality.blunder);
    });
  });

  group('MoveClassifier.deltaCp — perspective handling', () {
    test('white mover: loss when eval drops', () {
      expect(
        MoveClassifier.deltaCp(
          best: const EvalScore.cp(50),
          after: const EvalScore.cp(-30),
          moverColor: 'w',
        ),
        80,
      );
    });

    test('black mover: loss when eval rises (White improves)', () {
      expect(
        MoveClassifier.deltaCp(
          best: const EvalScore.cp(-50),
          after: const EvalScore.cp(120),
          moverColor: 'b',
        ),
        170,
      );
    });

    test('improvement over engine line clamps to zero', () {
      expect(
        MoveClassifier.deltaCp(
          best: const EvalScore.cp(10),
          after: const EvalScore.cp(60),
          moverColor: 'w',
        ),
        0,
      );
    });

    test('missing a mate counts as a huge loss', () {
      final delta = MoveClassifier.deltaCp(
        best: const EvalScore.mate(2),
        after: const EvalScore.cp(200),
        moverColor: 'w',
      );
      expect(MoveClassifier.classify(delta), MoveQuality.blunder);
    });

    test('walking into being mated as Black mover', () {
      final delta = MoveClassifier.deltaCp(
        best: const EvalScore.cp(-40),
        after: const EvalScore.mate(3),
        moverColor: 'b',
      );
      expect(MoveClassifier.classify(delta), MoveQuality.blunder);
    });
  });

  group('brilliancy', () {
    test('sacrifice threshold is 150cp inclusive', () {
      expect(
        MoveClassifier.isSacrifice(
            moverMaterialBeforeCp: 3900, moverMaterialAfterReplyCp: 3750),
        isTrue,
      );
      expect(
        MoveClassifier.isSacrifice(
            moverMaterialBeforeCp: 3900, moverMaterialAfterReplyCp: 3751),
        isFalse,
      );
    });

    test('only engine-best moves upgrade to brilliant', () {
      expect(
        MoveClassifier.withBrilliancy(MoveQuality.best, sacrifice: true),
        MoveQuality.brilliant,
      );
      expect(
        MoveClassifier.withBrilliancy(MoveQuality.best, sacrifice: false),
        MoveQuality.best,
      );
      expect(
        MoveClassifier.withBrilliancy(MoveQuality.good, sacrifice: true),
        MoveQuality.good,
      );
    });
  });

  group('accuracy', () {
    test('matches the web quality map', () {
      expect(
        MoveClassifier.accuracy([
          MoveQuality.brilliant,
          MoveQuality.best,
          MoveQuality.good,
          MoveQuality.inaccuracy,
          MoveQuality.mistake,
          MoveQuality.blunder,
        ]),
        closeTo((100 + 100 + 85 + 60 + 30 + 10) / 6, 0.001),
      );
    });

    test('empty input yields null', () {
      expect(MoveClassifier.accuracy(const []), isNull);
    });
  });
}
