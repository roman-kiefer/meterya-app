import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'l10n/app_localizations.dart';
import 'main.dart' show errorText;
import 'models.dart';
import 'photo_model.dart';

/// Displays the current booked reading independently of an immutable photo snapshot.
class BookedReadingValues extends StatelessWidget {
  final Point point;
  final Reading reading;
  const BookedReadingValues({
    super.key,
    required this.point,
    required this.reading,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final register = point.registers
        .where((r) => r.id == reading.registerId)
        .firstOrNull;
    final parsed = DateTime.tryParse(reading.date);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.photoBookedValues,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('${point.name} · ${point.serial}'),
            if (register != null)
              Text(
                '${l.photoRegister}: ${register.unit == 'kWh' ? (register.direction == 'EXPORT' ? l.photoExport : l.photoImport) : l.consumptionRegister}',
              ),
            Text(
              '${l.readingDateHeader}: ${parsed == null ? reading.date : DateFormat.yMd(l.localeName).format(parsed)}',
            ),
            Text(
              '${l.photoValue}: ${displayQuantity(reading.value)} ${register?.unit ?? ''}',
            ),
          ],
        ),
      ),
    );
  }
}

/// Protected photo preview shared by viewing, correcting and retracting a reading.
class ReadingPhotoPreview extends StatefulWidget {
  final ApiService api;
  final ReadingPhoto photo;
  const ReadingPhotoPreview({
    super.key,
    required this.api,
    required this.photo,
  });
  @override
  State<ReadingPhotoPreview> createState() => _ReadingPhotoPreviewState();
}

class _ReadingPhotoPreviewState extends State<ReadingPhotoPreview> {
  late Future<Uint8List> image = widget.api.photoBytes(widget.photo.previewURL);
  @override
  void didUpdateWidget(covariant ReadingPhotoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.previewURL != widget.photo.previewURL ||
        oldWidget.api != widget.api) {
      image = widget.api.photoBytes(widget.photo.previewURL);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.photo.status != 'CURRENT') ...[
          Text(
            l.photoConfirmedValues,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Text('${widget.photo.date} · ${displayQuantity(widget.photo.value)}'),
          Text(l.photoStatus(widget.photo.status)),
          const SizedBox(height: 12),
        ],
        SizedBox(
          height: 260,
          width: double.infinity,
          child: FutureBuilder<Uint8List>(
            future: image,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      errorText(
                        l,
                        snapshot.error is ApiException
                            ? (snapshot.error as ApiException).code
                            : 'INTERNAL_ERROR',
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(
                        () => image = widget.api.photoBytes(
                          widget.photo.previewURL,
                        ),
                      ),
                      child: Text(l.retryInvitationActivation),
                    ),
                  ],
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return InteractiveViewer(
                minScale: 1,
                maxScale: 8,
                child: Center(
                  child: Image.memory(snapshot.data!, fit: BoxFit.contain),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
