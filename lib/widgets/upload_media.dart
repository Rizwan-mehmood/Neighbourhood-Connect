import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis_auth/googleapis_auth.dart';

class GoogleDriveService {
  static const String _serviceAccountJson = '''{
  "type": "service_account",
  "project_id": "neighborhood-connect-56dc4",
  "private_key_id": "456a2c762fe8b42f93d3da75a791bf8082d1abfd",
  "private_key": "-----BEGIN PRIVATE KEY-----\\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQC7iamhP0ch5o7G\\nMP4OW0oPFfHu4MVou42+rp50EliBb9FltKlDWIm6FYh3fdyRQHe8S8srf26U0MxL\\nEmeWeMKH49Wh/T7VDnZQfizn498A6WFeEVua4tjYM7xX3QNK0pf6xqIeHF5hpqGD\\nBuKwbZsrNZfdeM3tD3K+oMONLhS8dvDs2PyrLFEETfo8C7Nq6vw8AXdAqZcQT5Fg\\na3KqknmWAqpE/5xuIONhOkZytN04bCMklrvaH6P2UQWtkGgvZxXGv238QGT+IpOg\\npXrkptIj5MJjZYSg7Jeh4sXVH9BEvoR3Y05p8BzLyllmAy5MNDRNCN2MUAEVTf1y\\nlbqnoUD1AgMBAAECggEAA6yzQDrCs9T0zpwLDlYWzOwWxAub3yS9/7QvE/GsxrdH\\nWhYUF1DPzYXsqd8+jbdwv8cd+n0gEyyUAsr+nTlu3w4pk2ei3WiNAV10EczclGgJ\\nZCd3LQmfjanQofCfmnTN0q0wkHLpEdLvMWeTyUPlk8xtbG93OznaDAbzhDjg+ERc\\nPCGXe8OBk0QrmpRPL8Odu7jdM0wmBHjFLvi0PROwvZgIWW2VInpt8JMR6kkIhvKU\\nl4KR+2hsPTA3E7BABYBuE8KGdcTzegUH4TBvI+9Yty1s7XJj3qLyF0QxcLXRB+AW\\nFchoC1SrlJHQJW9+CzYTB+whhJtXyqopW4TXxU3PrQKBgQD2DVggKxLtbGL9Tyci\\nmv5AvBwxpgt+F7lLSA1kOB85iLm2QXODTOw3YbghE5/tSXOvZK4ZEQxrk0yTp3y1\\nXa3VYFBgieeZmycbddsTozK35NH5AlUIu+Z14OCS0dfLIk24iuVGecEC/jRqhHH/\\nHPO3+9QkmGgqY8eMHKllFGnclwKBgQDDHrDPTEks/TLRJI6B8O+Y/J38qvtghTyJ\\nY/sOPUeKcSN31eHUqQUW8qTDLrNMa+TKUl5xuxC+Cr3oLL9kzr0WsCUgF8HHyWcJ\\nv8BlU8RAv25Uw3u31cMmfNC40Vj9sst8WsTCVBV8+WZ/4p5eHlXEvIFuKxO/aRlC\\nmj7IwbKkUwKBgEIODwyDw88Ne/25FC6MIZnLZl5Fz2wIfmwhacbv8iIF/KVbKOGk\\n8v1jNIVcuWCAiZgalUqRcx4mKzawjiA6iAJymuFv5Ecuie8rUqcQ9vq7aUtKPv3b\\nQ+F9f4yq3R3hla/nSeoDobdl+zhlWh087okECE3SxJQsuVN6FlfWhRz9AoGAYn2G\\ncE0ojs4MLafPS2YL+2Rgdx7znqgCg7N1EZ37E7XCWoYa5Vaf3BKE+oUDOmsn5Lyp\\nMa1kaRlQ/PZBcigtKFunkciMJ0XRfglNm5gp8yjuD1lRhN0hEbdlQDVkP0NWFaJX\\nuWPqKNhXVexVVlrnnlQs3ShfYnoxpv3m/T1Q6EMCgYAphl5/jT77WrGNgap3WXCS\\nUeK4jA9cwmaNTNFTipjt6V7vr9quh7rWbFakfI4bYuZLvI0q3izFEbeDW+bRSNO8\\nC2H3KtH20ammqpu64m9HUEDy3h1XdZFsaWWnIDqgLBDq15ZgDbTES30uz/KZYEtH\\nHVpkL8QLxdpjANs4z1bVnQ==\\n-----END PRIVATE KEY-----\\n",
  "client_email": "my-drive-uploader@neighborhood-connect-56dc4.iam.gserviceaccount.com",
  "client_id": "104634628188659645930",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/my-drive-uploader%40neighborhood-connect-56dc4.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com"
}''';

  static Future<String> uploadFile(File file, String fileName) async {
    // Use the drive file scope for regular file uploads.
    const scopes = [drive.DriveApi.driveFileScope];

    final credentials = ServiceAccountCredentials.fromJson(_serviceAccountJson);
    final client = await clientViaServiceAccount(credentials, scopes);

    try {
      final driveApi = drive.DriveApi(client);

      // Create a Drive file instance without setting appDataFolder as parent.
      final driveFile = drive.File()..name = fileName;

      final media = drive.Media(file.openRead(), await file.length());

      final result = await driveApi.files.create(driveFile, uploadMedia: media);
      final fileId = result.id;

      if (fileId != null) {
        final permission = drive.Permission(role: 'reader', type: 'anyone');
        await driveApi.permissions.create(permission, fileId);
      }

      final uploadedFile = await driveApi.files.get(
        fileId!,
        $fields: 'id,webContentLink',
      ) as drive.File;
      return uploadedFile.webContentLink ?? '';
    } catch (e) {
      print('Error uploading file to Google Drive: $e');
      rethrow;
    } finally {
      client.close();
    }
  }
}
