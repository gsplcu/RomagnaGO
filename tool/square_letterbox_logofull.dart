// Genera assets/logofull_square_for_launcher.png: canvas quadrato bianco con
// logofull.png ridimensionato in "contain" (nessun crop, nessuna distorsione).
// Usato da flutter_launcher_icons per icona tray / adaptive (il tool altrimenti
// forza quadrato distorto sul PNG rettangolare).
import 'dart:io';

import 'package:image/image.dart';

void main() {
  final root = Directory.current.path;
  final srcFile = File('$root/assets/logofull.png');
  final outFile = File('$root/assets/logofull_square_for_launcher.png');
  if (!srcFile.existsSync()) {
    stderr.writeln('Manca ${srcFile.path}');
    exitCode = 1;
    return;
  }

  final src = decodeImage(srcFile.readAsBytesSync());
  if (src == null) {
    stderr.writeln('Impossibile decodificare il PNG.');
    exitCode = 1;
    return;
  }

  const side = 2048;
  final canvas = Image(width: side, height: side);
  fill(canvas, color: ColorRgb8(255, 255, 255));

  final scale = (side / src.width < side / src.height) ? side / src.width : side / src.height;
  final w = (src.width * scale).round();
  final h = (src.height * scale).round();
  final resized = copyResize(src, width: w, height: h, interpolation: Interpolation.average);
  compositeImage(
    canvas,
    resized,
    dstX: (side - w) ~/ 2,
    dstY: (side - h) ~/ 2,
  );

  outFile.writeAsBytesSync(encodePng(canvas));
  stdout.writeln('Scritto ${outFile.path} (${side}x$side, logo ${w}x$h).');
}
