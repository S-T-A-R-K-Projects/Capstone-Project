//
//  GenAIWrapper.h
//  Runner
//
//  On-device LLM wrapper for text summarization using ONNX Runtime GenAI
//

#ifndef GenAIWrapper_h
#define GenAIWrapper_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol GenAIWrapperDelegate <NSObject>
- (void)didGenerateToken:(NSString *)token;
@end

@interface GenAIWrapper : NSObject

@property (nonatomic, weak) id<GenAIWrapperDelegate> delegate;

/// Load model from the specified directory path
/// @param modelPath Directory containing model files
/// @param error Error object if loading fails
/// @return YES if successful, NO otherwise
- (BOOL)load:(NSString *)modelPath error:(NSError **)error;

/// Run inference with the given prompt
/// @param prompt The input prompt for the model
/// @param params Search parameters (temperature, max_length, etc.)
/// @return YES if successful, NO otherwise
- (BOOL)inference:(NSString *)prompt withParams:(NSDictionary<NSString *, NSNumber *> *)params;

/// Unload the model and free resources
- (void)unload;

/// Stop the current generation
- (void)stopGeneration;

/// Check if model is currently loaded
- (BOOL)isLoaded;

@end

NS_ASSUME_NONNULL_END

#endif /* GenAIWrapper_h */
