import azure.functions as func
import logging
import csv
import json
import io

app = func.FunctionApp()


@app.function_name(name="TransformBlob")
@app.blob_trigger(
    arg_name="myblob",
    path="uploads/{name}",
    connection="BlobStorageConnectionString"
)
@app.blob_output(
    arg_name="outputblob",
    path="processed/{name}.json",
    connection="BlobStorageConnectionString"
)
def transform_blob(myblob: func.InputStream, outputblob: func.Out[str]) -> None:
    logging.info(
        "Python blob trigger processed a blob.\n"
        "Name: %s\n"
        "Blob Size: %s bytes",
        myblob.name,
        myblob.length
    )

    blob_content = myblob.read()

    try:
        text_content = blob_content.decode("utf-8-sig")
        csv_reader = csv.DictReader(io.StringIO(text_content))
        rows = [row for row in csv_reader]

        json_output = json.dumps(rows, indent=2)

        outputblob.set(json_output)

        logging.info(
            "Successfully transformed %s rows from CSV to JSON.",
            len(rows)
        )
    except Exception as e:
        logging.error("Failed to transform blob %s: %s", myblob.name, str(e))
        raise