// ignore_for_file: public_member_api_docs

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../../pdf.dart';
import '../../../widgets.dart';

class RoseGrid extends ChartGrid {
  RoseGrid({this.startAngle = 0});

  /// Start angle for the first [RoseDataSet]
  final double startAngle;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    super.layout(context, constraints, parentUsesSize: parentUsesSize);

    final datasets = Chart.of(context).datasets;

    final size = constraints.biggest;

    final _gridBox = PdfRect(0, 0, size.x, size.y);

    var _total = 0;

    _total = datasets.length;

    final unit = pi / _total * 2;
    var angle = startAngle;

    for (final dataset in datasets) {
      if (dataset is RoseDataSet) {
        dataset.angleStart = angle;
        angle += unit;
        dataset.angleEnd = angle;
        dataset.layout(context, BoxConstraints.tight(_gridBox.size));
        assert(dataset.box != null);
      }
    }
  }

  @override
  PdfPoint toChart(PdfPoint p) {
    return p;
  }

  void clip(Context context, PdfPoint size) {}

  @override
  void paint(Context context) {
    super.paint(context);

    final datasets = Chart.of(context).datasets;

    context.canvas
      ..saveContext()
      ..setTransform(
        Matrix4.translationValues(box!.width / 2, box!.height / 2, 0),
      );

    for (final dataSet in datasets) {
      if (dataSet is RoseDataSet) {
        dataSet.paintBackground(context);
      }
    }

    for (final dataSet in datasets) {
      if (dataSet is RoseDataSet) {
        dataSet.paint(context);
      }
    }

    for (final dataSet in datasets) {
      if (dataSet is RoseDataSet) {
        dataSet.paintLegend(context);
      }
    }

    context.canvas.restoreContext();
  }
}

enum RoseLegendPosition { none, auto, inside, outside }

class RoseDataSet extends Dataset {
  RoseDataSet({
    required this.value,
    String? legend,
    required PdfColor color,
    PdfColor? borderColor = PdfColors.white,
    double borderWidth = 1.5,
    bool? drawBorder,
    this.drawSurface = true,
    this.surfaceOpacity = 1,
    this.offset = 0,
    this.legendStyle,
    this.legendAlign,
    this.legendPosition = RoseLegendPosition.auto,
    this.legendLineWidth = 1.0,
    PdfColor? legendLineColor,
    Widget? legendWidget,
    this.legendOffset = 20,
    this.innerRadius = 0,
  })  : assert(innerRadius >= 0),
        assert(offset >= 0),
        drawBorder = drawBorder ?? borderColor != null && color != borderColor,
        assert((drawBorder ?? borderColor != null && color != borderColor) ||
            drawSurface),
        _legendWidget = legendWidget,
        legendLineColor = legendLineColor ?? color,
        super(
          legend: legend,
          color: color,
          borderColor: borderColor,
          borderWidth: borderWidth,
        );

  final num value;

  late double angleStart;

  late double angleEnd;

  final bool drawBorder;

  final bool drawSurface;

  final double surfaceOpacity;

  final double offset;

  final TextStyle? legendStyle;

  final TextAlign? legendAlign;
  final RoseLegendPosition legendPosition;

  Widget? _legendWidget;

  final double legendOffset;

  final double legendLineWidth;

  final PdfColor legendLineColor;

  final double innerRadius;

  PdfPoint? _legendAnchor;
  PdfPoint? _legendPivot;
  PdfPoint? _legendStart;

  bool get _isFullCircle => angleEnd - angleStart >= pi * 2;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    final _offset = _isFullCircle ? 0 : offset;

    final grid = Chart.of(context).grid as RoseGrid;
    final len = constraints.maxWidth;
    var x = -len;
    var y = -len;
    var w = len * 2;
    var h = len * 2;

    final lp = legendPosition == RoseLegendPosition.auto
        ? (angleEnd - angleStart > pi / 6
            ? RoseLegendPosition.inside
            : RoseLegendPosition.outside)
        : legendPosition;

    // Find the legend position
    final bisect = _isFullCircle ? 1 / 4 * pi : (angleStart + angleEnd) / 2;

    final _legendAlign = legendAlign ??
        (lp == RoseLegendPosition.inside
            ? TextAlign.center
            : (bisect > pi ? TextAlign.right : TextAlign.left));

    _legendWidget ??= legend == null
        ? null
        : RichText(
            text: TextSpan(
              children: [TextSpan(text: legend!, style: legendStyle)],
              style: TextStyle(
                  color: lp == RoseLegendPosition.inside
                      ? color!.isLight
                          ? PdfColors.white
                          : PdfColors.black
                      : null),
            ),
            textAlign: _legendAlign,
          );

    if (_legendWidget != null) {
      _legendWidget!
          .layout(context, BoxConstraints(maxWidth: value * grid.box!.width / 16, maxHeight: value * grid.box!.width / 16));
      assert(_legendWidget!.box != null);

      final ls = _legendWidget!.box!.size;

      // final style = Theme.of(context).defaultTextStyle.merge(legendStyle);

      switch (lp) {
        case RoseLegendPosition.outside:
          final o = value * grid.box!.width / 16 + legendOffset;
          final cx = sin(bisect) * (_offset + o);
          final cy = cos(bisect) * (_offset + o);

          _legendStart = PdfPoint(
            sin(bisect) * (_offset + o + legendOffset * 0.1),
            cos(bisect) * (_offset + o + legendOffset * 0.1),
          );

          _legendPivot = PdfPoint(cx, cy);
          if (bisect > pi) {
            _legendAnchor = PdfPoint(
              cx - legendOffset / 2 * 0.8,
              cy,
            );
            _legendWidget!.box = PdfRect.fromPoints(
                PdfPoint(
                  cx - legendOffset / 2 - ls.x,
                  cy - ls.y / 2,
                ),
                ls);
            w = max(w, (-cx + legendOffset / 2 + ls.x) * 2);
            h = max(h, cy.abs() * 2 + ls.y);
            x = -w / 2;
            y = -h / 2;
          } else {
            _legendAnchor = PdfPoint(
              cx + legendOffset / 2 * 0.8,
              cy,
            );
            _legendWidget!.box = PdfRect.fromPoints(
                PdfPoint(
                  cx + legendOffset / 2,
                  cy - ls.y / 2,
                ),
                ls);
            w = max(w, (cx + legendOffset / 2 + ls.x) * 2);
            h = max(h, cy.abs() * 2 + ls.y);
            x = -w / 2;
            y = -h / 2;
          }
          break;
        case RoseLegendPosition.inside:
          final double o;
          final double cx;
          final double cy;
          if (innerRadius == 0) {
            o = _isFullCircle ? 0 : value * grid.box!.width / 16 * 2 / 3;
            cx = sin(bisect) * (_offset + o);
            cy = cos(bisect) * (_offset + o);
          } else {
            o = (value * grid.box!.width / 16) / 2;
            if (_isFullCircle) {
              cx = 0;
              cy = o;
            } else {
              cx = sin(bisect) * (_offset + o);
              cy = cos(bisect) * (_offset + o);
            }
          }
          _legendWidget!.box = PdfRect.fromPoints(
              PdfPoint(
                cx - ls.x / 2,
                cy - ls.y / 2,
              ),
              ls);
          break;
        default:
          break;
      }
    }

    box = PdfRect(x, y, w, h);
  }

  void _paintSliceShape(Context context) {
    final grid = Chart.of(context).grid as RoseGrid;

    final bisect = (angleStart + angleEnd) / 2;

    final cx = sin(bisect) * offset;
    final cy = cos(bisect) * offset;

    final sx = cx + sin(angleStart) * value * grid.box!.width / 16;
    final sy = cy + cos(angleStart) * value * grid.box!.width / 16;
    final ex = cx + sin(angleEnd) * value * grid.box!.width / 16;
    final ey = cy + cos(angleEnd) * value * grid.box!.width / 16;

    if (_isFullCircle) {
      context.canvas
          .drawEllipse(0, 0, value * grid.box!.width / 16, value * grid.box!.width / 16);
    } else {
      context.canvas
        ..moveTo(cx, cy)
        ..lineTo(sx, sy)
        ..bezierArc(
            sx, sy, value * grid.box!.width / 16, value * grid.box!.width / 16, ex, ey,
            large: angleEnd - angleStart > pi);
    }
  }

  void _paintDonnutShape(Context context) {
    final grid = Chart.of(context).grid as RoseGrid;

    final bisect = (angleStart + angleEnd) / 2;

    final cx = sin(bisect) * offset;
    final cy = cos(bisect) * offset;

    final stx =
        cx + sin(angleStart) * value * grid.box!.width / 16; //innerRadius * 2;
    final sty = cy + cos(angleStart) * value *grid.box!.width / 16;
    final etx = cx + sin(angleEnd) * value * grid.box!.width / 16;
    final ety = cy + cos(angleEnd) * value * grid.box!.width / 16;
    final sbx = cx + sin(angleStart) * innerRadius;
    final sby = cy + cos(angleStart) * innerRadius;
    final ebx = cx + sin(angleEnd) * innerRadius;
    final eby = cy + cos(angleEnd) * innerRadius;

    if (_isFullCircle) {
      context.canvas.drawEllipse(0, 0, value.toDouble() * grid.box!.width / 16,
          value.toDouble() * grid.box!.width / 16);
      context.canvas
          .drawEllipse(0, 0, innerRadius, innerRadius, clockwise: false);
    } else {
      context.canvas
        ..moveTo(stx, sty)
        ..bezierArc(stx, sty, value.toDouble() * grid.box!.width / 16,
            value.toDouble() * grid.box!.width / 16, etx, ety,
            large: angleEnd - angleStart > pi)
        ..lineTo(ebx, eby)
        ..bezierArc(ebx, eby, innerRadius, innerRadius, sbx, sby,
            large: angleEnd - angleStart > pi, sweep: true)
        ..lineTo(stx, sty);
    }
  }

  void _paintShape(Context context) {
    if (innerRadius == 0) {
      _paintSliceShape(context);
    } else {
      _paintDonnutShape(context);
    }
  }

  @override
  void paintBackground(Context context) {
    super.paint(context);

    if (drawSurface) {
      _paintShape(context);
      if (surfaceOpacity != 1) {
        context.canvas
          ..saveContext()
          ..setGraphicState(
            PdfGraphicState(opacity: surfaceOpacity),
          );
      }

      context.canvas
        ..setFillColor(color)
        ..fillPath();

      if (surfaceOpacity != 1) {
        context.canvas.restoreContext();
      }
    }
  }

  @override
  void paint(Context context) {
    super.paint(context);

    if (drawBorder) {
      _paintShape(context);
      context.canvas
        ..setLineWidth(borderWidth)
        ..setLineJoin(PdfLineJoin.round)
        ..setStrokeColor(borderColor ?? color)
        ..strokePath(close: true);
    }
  }

  @protected
  void paintLegend(Context context) {
    if (legendPosition != RoseLegendPosition.none && _legendWidget != null) {
      if (_legendAnchor != null &&
          _legendPivot != null &&
          _legendStart != null) {
        context.canvas
          ..saveContext()
          ..moveTo(_legendStart!.x, _legendStart!.y)
          ..lineTo(_legendPivot!.x, _legendPivot!.y)
          ..lineTo(_legendAnchor!.x, _legendAnchor!.y)
          ..setLineWidth(legendLineWidth)
          ..setLineCap(PdfLineCap.round)
          ..setLineJoin(PdfLineJoin.round)
          ..setStrokeColor(legendLineColor)
          ..strokePath()
          ..restoreContext();
      }

      _legendWidget!.paint(context);
    }
  }

  @override
  void debugPaint(Context context) {
    super.debugPaint(context);

    final grid = Chart.of(context).grid as RoseGrid;

    final bisect = (angleStart + angleEnd) / 2;

    final cx = sin(bisect) * (offset + value + legendOffset);
    final cy = cos(bisect) * (offset + value + legendOffset);

    if (_legendWidget != null) {
      context.canvas
        ..saveContext()
        ..moveTo(0, 0)
        ..lineTo(cx, cy)
        ..setLineWidth(0.5)
        ..setLineDashPattern([3, 1])
        ..setStrokeColor(PdfColors.blue)
        ..strokePath()
        ..restoreContext();
    }
  }
}
