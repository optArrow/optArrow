MATLAB interface for OptArrow
=============================

To use MATLAB for OptArrow Service, there are 3 options:

1. Call Python code directly
----------------------------

This requires the service of Julia and Python engine to be running. Use MATLAB code to call `src/compute.py` directly, you can refer to the sample code below:

.. code-block:: matlab

   % Call when the python/julia service is up.
   
   %% ==== Set Python Virtual Environment ====
   % ⚠️ Change this to your venv python absolute path (recommend absolute path for clarity)
   venvPython = "path/to/your/python/executable/file";
   
   % Example (Linux/Mac):
   % venvPython = fullfile(pwd, ".venv", "bin", "python");
   % Example (Windows):
   % venvPython = fullfile(pwd, ".venv", "Scripts", "python.exe");
   
   pyenv("Version", venvPython);
   
   %% ==== Add project src path ====
   % ⚠️ Change this to your project src path
   insert(py.sys.path, int32(0), "path/to/optarrow/src");
   
   % Example (Linux/Mac):
   % insert(py.sys.path, int32(0), fullfile(pwd, "src"));
   % Example (Windows):
   % insert(py.sys.path, int32(0), "D:\Work\arrow_gateway_engine\src");
   
   %% ==== Prepare Data ====
   % Solver configuration
   solver = struct("solver_name", "glpk", "solver_type", "LP", "solver_params", struct());
   
   % Model data file
   matFile   = "path/to/your/model/data/file";
   % Example (Linux/Mac):
   % matFile = fullfile(pwd, "testdata", "e_coli_core.mat");
   
   % Python compute script
   computePy = "path/to/optarrow/src/compute.py";
   % Example (Linux/Mac):
   % computePy = fullfile(pwd, "src", "compute.py");
   
   %% ==== Run Python ====
   result_py = struct( pyrunfile(computePy, "result", mat_file=matFile, engine="python", solver=solver) );
   
   %% ==== Run Julia ====
   result_jl = struct( pyrunfile(computePy, "result", mat_file=matFile, engine="julia", solver=solver) );
   

This method allows using .mat file directly as long as it follows the same file structure as the featured `e_coli_core.mat` model.

2. Call HTTP web service
------------------------

Send request to address `https://your_FastAPI_service_ip:port/compute`. This requires sending a POST request with content type of `application/vnd.apache.arrow.stream`. This can be achieved by using MATLAB’s **HTTP Interface**, not the simpler `webwrite` function as stated below. Alternatively you can use `/computeJSON` to send and receive JSON data, but this would be slower than using Arrow (0.01 seconds slower than `/compute` using the `e_coli_core` model, performance difference would be much greater when using a larger model).

Using MATLAB’s `matlab.net.http` Interface to send `application/vnd.apache.arrow.stream` data
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

1. **Read your Arrow file into a `uint8` array**, for example using:

.. code-block:: matlab

      fid = fopen('data.arrow','rb');
      data = fread(fid, Inf, '*uint8');
      fclose(fid);

2. **Construct a POST request using `RequestMessage`**, explicitly setting the header and sending raw bytes without conversion:

.. code-block:: matlab

      import matlab.net.http.*
      import matlab.net.http.field.*
   
      % Create the request with custom header
      headers = [GenericField('Content-Type', 'application/vnd.apache.arrow.stream')];
      body = MessageBody();
      body.Payload = data;  % Ensures MATLAB sends raw bytes without conversion
      request = RequestMessage('POST', headers, body);
   
      % Optionally suppress default header alterations
      request.Completed = true;
   
      % Send the request
      uri = 'https://your.endpoint.url/upload';
      response = request.send(uri);

Alternative (Older) Approach: `urlreadpost`
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

You might also come across a community-contributed utility, **`urlreadpost`**, designed to upload binary data via HTTP using `multipart/form-data`. However, this approach is limited:

* It wraps files in a multipart form, not suitable for sending raw Arrow IPC streams.
* `urlreadpost` isn't part of MATLAB's core and works via a more old-school `urlread` replacement ([MathWorks][2], [ww2.mathworks.cn][3]).

Therefore, while interesting historically, it's not ideal for the Arrow streaming case.

---

Summary
^^^^^^^

| Requirement                      | Recommended Solution                                                      |
| -------------------------------- | ------------------------------------------------------------------------- |
| Send Arrow binary over HTTP      | Use `matlab.net.http.RequestMessage` + `body.Payload`                     |
| Set Content-Type to Arrow stream | Use `GenericField('Content-Type', 'application/vnd.apache.arrow.stream')` |
| Avoid MATLAB data conversion     | Assign to `body.Payload` (not `.Data`)                                    |
| Old methods available            | `urlreadpost` (multipart only, not raw streaming)                         |

[1]: https://www.mathworks.com/help/matlab/ref/matlab.net.http.requestmessage.send.html?utm_source=chatgpt.com "matlab.net.http.RequestMessage.send - Send HTTP request message and ..."
[2]: https://www.mathworks.com/matlabcentral/fileexchange/27189-urlreadpost-url-post-method-with-binary-file-uploading?utm_source=chatgpt.com "urlreadpost - url POST method with binary file uploading"
[3]: https://ww2.mathworks.cn/matlabcentral/fileexchange/27189-urlreadpost-url-post-method-with-binary-file-uploading?utm_source=chatgpt.com "urlreadpost - url POST method with binary file uploading"

3. Call socket service for Julia directly
-----------------------------------------

As MATLAB natively support sockets, it's possible to call julia service directly as it's exposed using sockets. This is not recommended however as this is a non-standard way of using this service and more data processing is required on the MATLAB side.

It's not possible to call gRPC service in MATLAB directly, to use Python engine, please use the other 2 methods.
