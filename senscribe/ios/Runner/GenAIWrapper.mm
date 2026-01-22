//
//  GenAIWrapper.mm
//  Runner
//
//  On-device LLM wrapper for text summarization using ONNX Runtime GenAI
//

#import "GenAIWrapper.h"
#include <onnxruntime-genai/ort_genai.h>
#include <onnxruntime-genai/ort_genai_c.h>
#include <string>

@implementation GenAIWrapper {
    OgaModel* _model;
    OgaTokenizer* _tokenizer;
    BOOL _isInferencing;
}

- (BOOL)isLoaded {
    return _model != nullptr && _tokenizer != nullptr;
}

- (void)stopGeneration {
    // Not implemented in simple version
}

- (BOOL)load:(NSString *)modelPath error:(NSError **)error {
    // Prevent duplicate loading
    if (_model != nullptr) {
        NSLog(@"GenAIWrapper: Model already loaded, skipping");
        return YES;
    }
    
    const char* modelPathCStr = [modelPath UTF8String];
    NSLog(@"GenAIWrapper: Loading model from path: %s", modelPathCStr);
    
    OgaResult* result = OgaCreateModel(modelPathCStr, &_model);
    if (result) {
        NSLog(@"GenAIWrapper: Failed to create model: %s", OgaResultGetError(result));
        if (error) {
            *error = [NSError errorWithDomain:@"GenAIWrapper"
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithUTF8String:OgaResultGetError(result)]}];
        }
        OgaDestroyResult(result);
        return NO;
    }
    NSLog(@"GenAIWrapper: Model created successfully");
    
    result = OgaCreateTokenizer(_model, &_tokenizer);
    if (result) {
        NSLog(@"GenAIWrapper: Failed to create tokenizer: %s", OgaResultGetError(result));
        if (error) {
            *error = [NSError errorWithDomain:@"GenAIWrapper"
                                         code:1002
                                     userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithUTF8String:OgaResultGetError(result)]}];
        }
        OgaDestroyResult(result);
        OgaDestroyModel(_model);
        _model = nullptr;
        return NO;
    }
    NSLog(@"GenAIWrapper: Tokenizer created successfully");
    
    return YES;
}


- (BOOL)inference:(nonnull NSString *)prompt withParams:(NSDictionary<NSString *, NSNumber *> *)params {
    // Guard against concurrent inference
    if (_isInferencing) {
        NSLog(@"GenAIWrapper: Inference already in progress, skipping");
        return NO;
    }
    _isInferencing = YES;
    
    NSLog(@"GenAIWrapper: Starting inference");
    
    BOOL success = NO;
    OgaSequences* sequences = nullptr;
    OgaGeneratorParams* genParams = nullptr;
    OgaTokenizerStream* tokenizerStream = nullptr;
    OgaGenerator* generator = nullptr;
    
    // Create sequences
    OgaResult* result = OgaCreateSequences(&sequences);
    if (result) {
        NSLog(@"GenAIWrapper: Failed to create sequences: %s", OgaResultGetError(result));
        OgaDestroyResult(result);
        goto cleanup;
    }
    
    // Encode prompt
    result = OgaTokenizerEncode(_tokenizer, [prompt UTF8String], sequences);
    if (result) {
        NSLog(@"GenAIWrapper: Failed to encode: %s", OgaResultGetError(result));
        OgaDestroyResult(result);
        goto cleanup;
    }
    
    {
        size_t inputTokenCount = OgaSequencesGetSequenceCount(sequences, 0);
        NSLog(@"GenAIWrapper: Encoded %zu input tokens", inputTokenCount);
    }
    
    // Create generator params
    NSLog(@"GenAIWrapper: Creating generator params...");
    result = OgaCreateGeneratorParams(_model, &genParams);
    if (result) {
        NSLog(@"GenAIWrapper: Failed to create generator params: %s", OgaResultGetError(result));
        OgaDestroyResult(result);
        goto cleanup;
    }
    NSLog(@"GenAIWrapper: Generator params created");
    
    // Set max_length to 512 for testing (input ~457 + output ~55)
    OgaGeneratorParamsSetSearchNumber(genParams, "max_length", 512);
    
    // Create tokenizer stream
    NSLog(@"GenAIWrapper: Creating tokenizer stream...");
    result = OgaCreateTokenizerStream(_tokenizer, &tokenizerStream);
    if (result) {
        NSLog(@"GenAIWrapper: Failed to create tokenizer stream: %s", OgaResultGetError(result));
        OgaDestroyResult(result);
        goto cleanup;
    }
    NSLog(@"GenAIWrapper: Tokenizer stream created");
    
    // Create generator
    NSLog(@"GenAIWrapper: Creating generator (this may take a while)...");
    result = OgaCreateGenerator(_model, genParams, &generator);
    if (result) {
        NSLog(@"GenAIWrapper: Failed to create generator: %s", OgaResultGetError(result));
        OgaDestroyResult(result);
        goto cleanup;
    }
    NSLog(@"GenAIWrapper: Generator created");
    
    // Append input sequences
    NSLog(@"GenAIWrapper: Appending sequences...");
    result = OgaGenerator_AppendTokenSequences(generator, sequences);
    if (result) {
        NSLog(@"GenAIWrapper: Failed to append sequences: %s", OgaResultGetError(result));
        OgaDestroyResult(result);
        goto cleanup;
    }
    NSLog(@"GenAIWrapper: Generator ready, starting token generation");
    
    // Generate tokens
    {
        int tokenCount = 0;
        while (!OgaGenerator_IsDone(generator)) {
            result = OgaGenerator_GenerateNextToken(generator);
            if (result) {
                NSLog(@"GenAIWrapper: Failed to generate token: %s", OgaResultGetError(result));
                OgaDestroyResult(result);
                break;
            }
            
            size_t seqLen = OgaGenerator_GetSequenceCount(generator, 0);
            if (seqLen == 0) continue;
            
            const int32_t* seqData = OgaGenerator_GetSequenceData(generator, 0);
            int32_t newToken = seqData[seqLen - 1];
            
            tokenCount++;
            
            // Decode token
            const char* decodedChunk = nullptr;
            result = OgaTokenizerStreamDecode(tokenizerStream, newToken, &decodedChunk);
            if (result) {
                OgaDestroyResult(result);
                continue;
            }
            
            if (decodedChunk != nullptr && strlen(decodedChunk) > 0) {
                std::string decodedStr(decodedChunk);
                NSString* nsDecodedStr = [NSString stringWithUTF8String:decodedStr.c_str()];
                if (nsDecodedStr != nil && [nsDecodedStr length] > 0) {
                    if (tokenCount <= 5) {
                        NSLog(@"GenAIWrapper: Token %d: '%@'", tokenCount, nsDecodedStr);
                    }
                    if (self.delegate && [self.delegate respondsToSelector:@selector(didGenerateToken:)]) {
                        [self.delegate didGenerateToken:nsDecodedStr];
                    }
                }
            }
        }
        NSLog(@"GenAIWrapper: Inference complete, generated %d tokens", tokenCount);
        success = YES;
    }
    
cleanup:
    if (generator) OgaDestroyGenerator(generator);
    if (tokenizerStream) OgaDestroyTokenizerStream(tokenizerStream);
    if (genParams) OgaDestroyGeneratorParams(genParams);
    if (sequences) OgaDestroySequences(sequences);
    
    _isInferencing = NO;
    return success;
}

- (void)unload {
    NSLog(@"GenAIWrapper: Unloading model");
    if (_tokenizer) {
        OgaDestroyTokenizer(_tokenizer);
        _tokenizer = nullptr;
    }
    if (_model) {
        OgaDestroyModel(_model);
        _model = nullptr;
    }
    _isInferencing = NO;
}

@end
