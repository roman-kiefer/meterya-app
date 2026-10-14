import 'package:flutter/material.dart';
import 'api_service.dart';
import 'models.dart';
import 'l10n/app_localizations.dart';
import 'photo_model.dart';
import 'report_delivery.dart';
import 'reading_photo_evidence.dart';

class PhotoGallery extends StatelessWidget {
  final ApiService api;
  final List<ReadingPhoto> photos;
  final Point point;
  final Reading reading;
  const PhotoGallery({
    super.key,
    required this.api,
    required this.photos,
    required this.point,
    required this.reading,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.photoGallery),
      content: SizedBox(
        width: 800,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .65,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BookedReadingValues(point: point, reading: reading),
                for (final photo in photos)
                  Card(
                    key: ValueKey(photo.id),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ReadingPhotoPreview(api: api, photo: photo),
                          TextButton.icon(
                            onPressed: () => downloadReportURL(
                              api.base
                                  .resolve(
                                    photo.editedURL.isEmpty
                                        ? photo.originalURL
                                        : photo.editedURL,
                                  )
                                  .toString(),
                              photo.id,
                            ),
                            icon: const Icon(Icons.download_outlined),
                            label: Text(l.photoEditedDownload),
                          ),
                          TextButton.icon(
                            onPressed: () => downloadReportURL(
                              api.base.resolve(photo.originalURL).toString(),
                              photo.id,
                            ),
                            icon: const Icon(Icons.download_outlined),
                            label: Text(l.photoOriginal),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
      ],
    );
  }
}
