stag
====
Stupid Typed Attribute Generator

Why
---
Since the advent of the personal computer, doctors and scientists have been
confounded by the persistence and virility of Overactive Type Annotation
Syndrome (OTAS). Despite decades of experience, the widespread availability
of cognitive behavioral therapy, and even a proposed vaccine, no regimen has
been shown effective for the treatment or prevention of OTAS.

Victims of the disease exhibit broad dysfunction. They agonize over
irrelevant details of code rendering, produce thousands of lines of
redundant or unnecessary code, and generally waste the time and energy of
unaffected individuals.

The leading theory of OTAS's pathology comes from Freud, who postulated that
the patient's subconscious desire to control elimination might manifest as a
preoccupation with technical rigidity and verbosity. However, no clinical
study to date supports this theory.

Alternative proposed modes of pathology typically involve small
mind-controlling parasites or latent food allergies. Some people display
apparent immunity to OTAS, and it is not known whether immunity is acquired
or hereditary.

What
----
`stag` is a Racket program that, given an XML Schema Definition (XSD) file,
generates two python modules: one containing python classes corresponding to
the types defined in the schema, and another of utilities for converting
instances of the generated classes to and from JSON-compatible compositions
of standard python objects, (such as `dict` and `list`).

How
---
Invoke `stag` as a command line tool:

    $ ./stag foosvcmsg foosvc_flat.xsd
    $ ls
    foosvcmsg.py    foosvcmsgutil.py

To the current directory or a specified directory the script writes two
files: one containing the generated class definitions (`foosvcmsg.py`), and
another containing the implementations of the `to_json` and `from_json`
functions (`foosvcmsgutil.py`).

`stag` also accepts various options:

<table>
  <tr><th>Option</th><th>Description</th></tr>
  <tr><td><pre><code>--util-module &lt;name&gt; </code></pre></td>
      <td>Override the name of the utilities module.</td></tr>
  <tr><td>TODO...</td>
      <td>TODO...</td></tr>
</table>
