
# import sys
# sys.path.append('./.local/lib/python3.6/site-packages/')
# import kale
from kale.sdk import pipeline, step


@step(name="data_processing")
def process(timestamp):
    import remote_service_lib
    from local_package import data_processor

    data = remote_service_lib.get_data(timestamp)
    train, validate = data_processor(data)
    return train, validate

@step(name="data_validation")
def validate(train_data, validate_data):
    from local_package import data_validator

    # data_validator raises an exception if data is not valid
    train, validate = data_validator(train_data, validate_data)
    return train, validate

@step(name="model_training")
def train(train_data, validate_data, training_iterations):

    model = Model(training_iterations)
    model.train(train_data)
    print(model.predict(validate_data))
    
@pipeline(name="model_training", experiment="kale_sdk_pipeline")  
def ml_experiment(ts, iters):
  train, validate = process(ts)
  train_valid, validate_valid = validate(train, validate)
  train(train_valid, validate_valid, iters)

if __name__ == "__main__":
  # Note: reading arguments directly from `sys.argv` is not a good
  # practice in general. Consider using some specific library, like
  # `argparse`
  ts = sys.argv[1]
  iters = sys.argv[2]
  ml_experiments(ts="...", iters=10)
