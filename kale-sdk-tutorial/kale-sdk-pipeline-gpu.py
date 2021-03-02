
from kale.sdk import pipeline, step

@step(name="my_step")
def foo(a):
    # Using a relative import to another local script will work as long as
    # you are using rok to snapshot the current environment and mount a clone
    # of the volume in the pipeline step:
    # from .script import bar
    import sys
    sys.stdout.write(a)
    # return multiple values. These could be used by different subsequent
    # pipeline steps.
    return "Some", "Data"


@step(name="second_step")
def foo2(b, c):
    print(b + c)


@step(name="third_step")
def foo3(b, c):
    print(b + c)

@pipeline(name="test-pipeline",
          experiment="kale-sdk-tutorial")
def my_pipeline(parameter="input"):
    data1, data2 = foo(parameter)
    foo2(data1, parameter)
    foo3(data2, parameter)


if __name__ == "__main__":
    my_pipeline(parameter="example-param")
