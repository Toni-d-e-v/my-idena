import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:ethereum_util/ethereum_util.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:my_idena/backoffice/bean/flip_examples.dart';
import 'package:my_idena/backoffice/bean/flip_get_request.dart';
import 'package:my_idena/backoffice/bean/flip_get_response.dart';
import 'package:my_idena/backoffice/bean/flip_longHashes_request.dart';
import 'package:my_idena/backoffice/bean/flip_longHashes_response.dart';
import 'package:my_idena/backoffice/bean/flip_shortHashes_request.dart';
import 'package:my_idena/backoffice/bean/flip_shortHashes_response.dart';
import 'package:my_idena/backoffice/bean/flip_submitLongAnswers_request.dart';
import 'package:my_idena/backoffice/bean/flip_submitLongAnswers_response.dart';
import 'package:my_idena/backoffice/bean/flip_submitShortAnswers_request.dart';
import 'package:my_idena/backoffice/bean/flip_submitShortAnswers_response.dart';
import 'package:my_idena/backoffice/bean/flip_words_request.dart';
import 'package:my_idena/backoffice/bean/flip_words_response.dart';
import 'package:my_idena/beans/dictWords.dart';
import 'package:my_idena/utils/epoch_period.dart' as EpochPeriod;
import 'package:my_idena/utils/relevance_type.dart' as RelevantType;
import 'package:my_idena/utils/sharedPreferencesHelper.dart';
import 'package:ethereum_util/src/rlp.dart' as Rlp;

var logger = Logger();

class ValidationSessionInfoFlips {
  ValidationSessionInfoFlips(
      {this.hash,
      this.ready,
      this.extra,
      this.available,
      this.listWords,
      this.listImagesLeft,
      this.listImagesRight,
      this.listOk});

  String hash;
  bool ready;
  bool extra;
  bool available;
  List<Word> listWords;
  List<Uint8List> listImagesLeft;
  List<Uint8List> listImagesRight;
  int listOk;
}

class ValidationSessionInfo {
  ValidationSessionInfo({this.typeSession, this.listSessionValidationFlip});

  String typeSession;
  List<ValidationSessionInfoFlips> listSessionValidationFlip;
  List<ValidationSessionInfoFlips> listSessionValidationFlipExtra;
}

Future<ValidationSessionInfo> getValidationSessionInfo(
    String typeSession,
    ValidationSessionInfo validationSessionInfoInput,
    bool simulationMode) async {
  if (validationSessionInfoInput != null) {
    return validationSessionInfoInput;
  }

  ValidationSessionInfo validationSessionInfo = new ValidationSessionInfo();
  String method;

  switch (typeSession) {
    case EpochPeriod.ShortSession:
      {
        method = FlipShortHashesRequest.METHOD_NAME;
      }
      break;
    case EpochPeriod.LongSession:
      {
        method = FlipLongHashesRequest.METHOD_NAME;
      }
      break;
    default:
      return validationSessionInfo;
  }

  FlipShortHashesRequest flipShortHashesRequest;
  FlipShortHashesResponse flipShortHashesResponse;
  FlipLongHashesRequest flipLongHashesRequest;
  FlipLongHashesResponse flipLongHashesResponse;

  try {
    HttpClient httpClient = new HttpClient();
    IdenaSharedPreferences idenaSharedPreferences =
        await SharedPreferencesHelper.getIdenaSharedPreferences();

    Map<String, dynamic> dictWordsDdata;
    List wordsMap;
    if (typeSession == EpochPeriod.LongSession) {
      DictWords dictWordsList = await DictWords().getDictWords();
      dictWordsDdata = dictWordsList.toJson();
      wordsMap = dictWordsDdata["words"];
    }

    if (simulationMode) {
      if (typeSession == EpochPeriod.ShortSession) {
        flipShortHashesResponse = FlipShortHashesResponse.fromJson(
            FlipExamples().getMapExample(typeSession));
      }
      if (typeSession == EpochPeriod.LongSession) {
        flipLongHashesResponse = FlipLongHashesResponse.fromJson(
            FlipExamples().getMapExample(typeSession));
      }
    } else {
      HttpClientRequest request =
          await httpClient.postUrl(Uri.parse(idenaSharedPreferences.apiUrl));
      request.headers.set('content-type', 'application/json');

      Map<String, dynamic> map = {
        'method': method,
        "params": [],
        'id': 101,
        'key': idenaSharedPreferences.keyApp
      };

      if (typeSession == EpochPeriod.ShortSession) {
        flipShortHashesRequest = FlipShortHashesRequest.fromJson(map);
        logger.i(
            new JsonEncoder.withIndent('  ').convert(flipShortHashesRequest));
        request.add(utf8.encode(json.encode(flipShortHashesRequest.toJson())));
        HttpClientResponse response = await request.close();
        if (response.statusCode == 200) {
          String reply = await response.transform(utf8.decoder).join();
          logger.i(reply);
          flipShortHashesResponse = flipShortHashesResponseFromJson(reply);
        }
      }
      if (typeSession == EpochPeriod.LongSession) {
        flipLongHashesRequest = FlipLongHashesRequest.fromJson(map);
        logger
            .i(new JsonEncoder.withIndent('  ').convert(flipLongHashesRequest));
        request.add(utf8.encode(json.encode(flipLongHashesRequest.toJson())));
        HttpClientResponse response = await request.close();
        if (response.statusCode == 200) {
          String reply = await response.transform(utf8.decoder).join();
          logger.i(reply);
          flipLongHashesResponse = flipLongHashesResponseFromJson(reply);
        }
      }
    }

    FlipGetResponse flipGetResponse;
    FlipWordsResponse flipWordsResponse;
    List<ValidationSessionInfoFlips> listSessionValidationFlip = new List();
    List<ValidationSessionInfoFlips> listSessionValidationFlipExtra =
        new List();
    int nbFlips = 0;
    if (typeSession == EpochPeriod.ShortSession) {
      nbFlips = flipShortHashesResponse.result.length;
    }
    if (typeSession == EpochPeriod.LongSession) {
      nbFlips = flipLongHashesResponse.result.length;
    }

    for (int i = 0; i < nbFlips; i++) {
      ValidationSessionInfoFlips validationSessionInfoFlips =
          new ValidationSessionInfoFlips();
      if (typeSession == EpochPeriod.ShortSession) {
        validationSessionInfoFlips.hash =
            flipShortHashesResponse.result[i].hash;
        validationSessionInfoFlips.ready =
            flipShortHashesResponse.result[i].ready;
        validationSessionInfoFlips.extra =
            flipShortHashesResponse.result[i].extra;
        validationSessionInfoFlips.available =
            flipShortHashesResponse.result[i].available;
      }
      if (typeSession == EpochPeriod.LongSession) {
        validationSessionInfoFlips.hash = flipLongHashesResponse.result[i].hash;
        validationSessionInfoFlips.ready =
            flipLongHashesResponse.result[i].ready;
        validationSessionInfoFlips.extra =
            flipLongHashesResponse.result[i].extra;
        validationSessionInfoFlips.available =
            flipLongHashesResponse.result[i].available;
      }

      // get Flip
      if (simulationMode) {
        String data =
            await loadAssets(validationSessionInfoFlips.hash + "_images");
        flipGetResponse = flipGetResponseFromJson(data);
      } else {
        HttpClientRequest requestFlip =
            await httpClient.postUrl(Uri.parse(idenaSharedPreferences.apiUrl));
        requestFlip.headers.set('content-type', 'application/json');

        Map<String, dynamic> mapFlip = {
          'method': FlipGetRequest.METHOD_NAME,
          'params': [validationSessionInfoFlips.hash],
          'id': 101,
          'key': idenaSharedPreferences.keyApp
        };

        FlipGetRequest flipGetRequest = FlipGetRequest.fromJson(mapFlip);
        requestFlip.add(utf8.encode(json.encode(flipGetRequest.toJson())));
        HttpClientResponse responseFlip = await requestFlip.close();
        if (responseFlip.statusCode == 200) {
          String replyFlip = await responseFlip.transform(utf8.decoder).join();
          logger.i(replyFlip);
          flipGetResponse = flipGetResponseFromJson(replyFlip);
        }
      }

      Uint8List imageUint8_1;
      Uint8List imageUint8_2;
      Uint8List imageUint8_3;
      Uint8List imageUint8_4;

      Decoded images;
      Decoded privateImages;
      List listImages = new List(4);
      List orders = new List(2);
      if (flipGetResponse.result.privateHex != null &&
          flipGetResponse.result.privateHex != '0x') {
        // ;[images] = decode(publicHex || hex)
        if (flipGetResponse.result.publicHex != null) {
          images = Rlp.decode(
              Uint8List.fromList(toBuffer(flipGetResponse.result.publicHex)),
              true);
        } else {
          if (flipGetResponse.result.hex != null) {
            images = Rlp.decode(
                Uint8List.fromList(toBuffer(flipGetResponse.result.hex)), true);
          }
        }

        // let privateImages
        // ;[privateImages, orders] = decode(privateHex)
        privateImages = Rlp.decode(
            Uint8List.fromList(toBuffer(flipGetResponse.result.privateHex)),
            true);

        // images = images.concat(privateImages)
        imageUint8_1 = images.data[0][0];
        imageUint8_2 = images.data[0][1];
        imageUint8_3 = privateImages.data[0][0];
        imageUint8_4 = privateImages.data[0][1];
        listImages[0] = imageUint8_1;
        listImages[1] = imageUint8_2;
        listImages[2] = imageUint8_3;
        listImages[3] = imageUint8_4;
        orders = privateImages.data[1];
      } else {
        // TODO: implement this case
        // ;[images, orders] = decode(hex)
        var images3;
        images3 = Rlp.decode(
            Uint8List.fromList(toBuffer(flipGetResponse.result.hex)), true);
      }

      String order1 =
          orders[0][0].toString().replaceAll('[', '').replaceAll(']', '');
      String order2 =
          orders[0][1].toString().replaceAll('[', '').replaceAll(']', '');
      String order3 =
          orders[0][2].toString().replaceAll('[', '').replaceAll(']', '');
      String order4 =
          orders[0][3].toString().replaceAll('[', '').replaceAll(']', '');
      validationSessionInfoFlips.listImagesLeft = new List<Uint8List>(4);
      validationSessionInfoFlips.listImagesLeft[0] =
          listImages[int.tryParse(order1) ?? 0];
      validationSessionInfoFlips.listImagesLeft[1] =
          listImages[int.tryParse(order2) ?? 0];
      validationSessionInfoFlips.listImagesLeft[2] =
          listImages[int.tryParse(order3) ?? 0];
      validationSessionInfoFlips.listImagesLeft[3] =
          listImages[int.tryParse(order4) ?? 0];

      // TODO .. dirty
      order1 = orders[1][0].toString().replaceAll('[', '').replaceAll(']', '');
      order2 = orders[1][1].toString().replaceAll('[', '').replaceAll(']', '');
      order3 = orders[1][2].toString().replaceAll('[', '').replaceAll(']', '');
      order4 = orders[1][3].toString().replaceAll('[', '').replaceAll(']', '');
      validationSessionInfoFlips.listImagesRight = new List<Uint8List>(4);
      validationSessionInfoFlips.listImagesRight[0] =
          listImages[int.tryParse(order1) ?? 0];
      validationSessionInfoFlips.listImagesRight[1] =
          listImages[int.tryParse(order2) ?? 0];
      validationSessionInfoFlips.listImagesRight[2] =
          listImages[int.tryParse(order3) ?? 0];
      validationSessionInfoFlips.listImagesRight[3] =
          listImages[int.tryParse(order4) ?? 0];

      // get Words
      int nbWords = 0;
      if (typeSession == EpochPeriod.LongSession) {
        if (simulationMode) {
          try {
            String data = await loadAssets(
                flipLongHashesResponse.result[i].hash + "_words");
            flipWordsResponse = flipWordsResponseFromJson(data);
          } catch (e) {
            Map<String, dynamic> mapWords = {
              "jsonrpc": "2.0",
              "id": 51,
              "result": {
                "words": [0, 0]
              }
            };
            flipWordsResponse = FlipWordsResponse.fromJson(mapWords);
          }
          nbWords = flipWordsResponse.result.words.length;
        } else {
          try {
            HttpClientRequest requestWords = await httpClient
                .postUrl(Uri.parse(idenaSharedPreferences.apiUrl));
            requestWords.headers.set('content-type', 'application/json');
            Map<String, dynamic> mapWords = {
              'method': FlipWordsRequest.METHOD_NAME,
              'params': [flipLongHashesResponse.result[i].hash],
              'id': 101,
              'key': idenaSharedPreferences.keyApp
            };
            FlipWordsRequest flipWordsRequest =
                FlipWordsRequest.fromJson(mapWords);
            requestWords
                .add(utf8.encode(json.encode(flipWordsRequest.toJson())));
            logger.i(new JsonEncoder.withIndent('  ').convert(requestWords));
            HttpClientResponse responseWords = await requestWords.close();
            if (responseWords.statusCode == 200) {
              String replyWords =
                  await responseWords.transform(utf8.decoder).join();
              logger.i(replyWords);
              flipWordsResponse = flipWordsResponseFromJson(replyWords);
              nbWords = flipWordsResponse.result.words.length;
            }
          } catch (e) {}
        }

        List<Word> listWords = new List(nbWords);
        for (int j = 0; j < nbWords; j++) {
          Word word;
          if (flipWordsResponse.result.words[j] == 0) {
            word = new Word(name: "", desc: "");
          } else {
            word = new Word(
                name: wordsMap[flipWordsResponse.result.words[j]]["name"],
                desc: wordsMap[flipWordsResponse.result.words[j]]["desc"]);
          }
          listWords[j] = word;
        }
        validationSessionInfoFlips.listWords = listWords;
      }
      if (validationSessionInfoFlips.extra) {
        listSessionValidationFlipExtra.add(validationSessionInfoFlips);
      } else {
        listSessionValidationFlip.add(validationSessionInfoFlips);
      }
    }

    validationSessionInfo.listSessionValidationFlip = listSessionValidationFlip;
    validationSessionInfo.listSessionValidationFlipExtra =
        listSessionValidationFlipExtra;
  } catch (e) {
    logger.e(e.toString());
  } finally {}

  return validationSessionInfo;
}

Future<String> loadAssets(String fileName) async {
  try {
    return await rootBundle.loadString('test/examples/' + fileName + '.json');
  } catch (e) {
    return null;
  } finally {}
}

Future<FlipSubmitShortAnswersResponse> submitShortAnswers(
    List selectionFlipList, ValidationSessionInfo validationSessionInfo) async {
  if (validationSessionInfo == null) {
    return null;
  }
  FlipSubmitShortAnswersRequest flipSubmitShortAnswersRequest =
      new FlipSubmitShortAnswersRequest();
  FlipSubmitShortAnswersResponse flipSubmitShortAnswersResponse;

  try {
    HttpClient httpClient = new HttpClient();
    IdenaSharedPreferences idenaSharedPreferences =
        await SharedPreferencesHelper.getIdenaSharedPreferences();

    HttpClientRequest request =
        await httpClient.postUrl(Uri.parse(idenaSharedPreferences.apiUrl));
    request.headers.set('content-type', 'application/json');

    ParamShortAnswer answers = new ParamShortAnswer();
    List<ShortAnswer> listAnswers = new List();
    for (int i = 0; i < selectionFlipList.length; i++) {
      ShortAnswer answer = new ShortAnswer(
          answer: selectionFlipList[i],
          hash: validationSessionInfo.listSessionValidationFlip[i].hash);
      listAnswers.add(answer);
    }

    answers.epoch = 0;
    answers.nonce = 0;
    answers.answers = listAnswers;

    List<ParamShortAnswer> params = new List();
    params.add(answers);
    flipSubmitShortAnswersRequest.method =
        FlipSubmitShortAnswersRequest.METHOD_NAME;
    flipSubmitShortAnswersRequest.params = params;
    flipSubmitShortAnswersRequest.id = 101;
    flipSubmitShortAnswersRequest.key = idenaSharedPreferences.keyApp;

    request
        .add(utf8.encode(json.encode(flipSubmitShortAnswersRequest.toJson())));

    logger.i(new JsonEncoder.withIndent('  ')
        .convert(flipSubmitShortAnswersRequest));
    HttpClientResponse response = await request.close();
    if (response.statusCode == 200) {
      String reply = await response.transform(utf8.decoder).join();
      logger.i(reply);
      flipSubmitShortAnswersResponse =
          flipSubmitShortAnswersResponseFromJson(reply);
    }
  } catch (e) {
    logger.e(e.toString());
  } finally {}
  return flipSubmitShortAnswersResponse;
}

Future<FlipSubmitLongAnswersResponse> submitLongAnswers(List selectionFlipList,
    List relevantFlipList, ValidationSessionInfo validationSessionInfo) async {
  if (validationSessionInfo == null) {
    return null;
  }
  FlipSubmitLongAnswersRequest flipSubmitLongAnswersRequest =
      new FlipSubmitLongAnswersRequest();
  FlipSubmitLongAnswersResponse flipSubmitLongAnswersResponse;
  bool wrongWordsBool;
  try {
    HttpClient httpClient = new HttpClient();
    IdenaSharedPreferences idenaSharedPreferences =
        await SharedPreferencesHelper.getIdenaSharedPreferences();

    HttpClientRequest request =
        await httpClient.postUrl(Uri.parse(idenaSharedPreferences.apiUrl));
    request.headers.set('content-type', 'application/json');

    ParamLongAnswer answers = new ParamLongAnswer();
    List<LongAnswer> listAnswers = new List();
    for (int i = 0; i < selectionFlipList.length; i++) {
      if (selectionFlipList[i] != null) {
        wrongWordsBool = false;
        if (relevantFlipList[i] != null &&
            relevantFlipList[i] == RelevantType.IRRELEVANT) {
          wrongWordsBool = true;
        }
        LongAnswer answer = new LongAnswer(
            answer: selectionFlipList[i],
            wrongWords: wrongWordsBool,
            hash: validationSessionInfo.listSessionValidationFlip[i].hash);
        listAnswers.add(answer);
      }
    }

    answers.epoch = 0;
    answers.nonce = 0;
    answers.answers = listAnswers;

    List<ParamLongAnswer> params = new List();
    params.add(answers);
    flipSubmitLongAnswersRequest.method =
        FlipSubmitLongAnswersRequest.METHOD_NAME;
    flipSubmitLongAnswersRequest.params = params;
    flipSubmitLongAnswersRequest.id = 101;
    flipSubmitLongAnswersRequest.key = idenaSharedPreferences.keyApp;

    request
        .add(utf8.encode(json.encode(flipSubmitLongAnswersRequest.toJson())));
    logger.i(
        new JsonEncoder.withIndent('  ').convert(flipSubmitLongAnswersRequest));
    HttpClientResponse response = await request.close();
    if (response.statusCode == 200) {
      String reply = await response.transform(utf8.decoder).join();
      logger.i(reply);
      flipSubmitLongAnswersResponse =
          flipSubmitLongAnswersResponseFromJson(reply);
    }
  } catch (e) {
    logger.e(e.toString());
  } finally {}
  return flipSubmitLongAnswersResponse;
}
