# Design Review Checklist

This is the primary review phase — checking that the project design is solid before building.

## README.md

- [ ] README.md exists in the repository root
- [ ] Contains a description of what the project is
- [ ] Contains instructions on how to build/use the project
- [ ] Contains motivation — why the author made it (doesn't need its own section, can be woven into other text)
- [ ] Contains a screenshot or render of the full 3D model (if project has a 3D model)
- [ ] Contains a screenshot of the PCB (if project has a PCB)
- [ ] Contains a wiring diagram (if project has wiring that isn't on a PCB)
- [ ] Contains a BOM table with component names, quantities, and purchase links where applicable

## Repository structure

- [ ] BOM file exists in CSV format with purchase links for components that are not custom-made, 3D printed, or through PCBA. Links are not required for: parts from well-known vendors where a part number suffices (LCSC, DigiKey, Mouser), parts already owned, or common/generic materials (screws, wire, popsicle sticks, etc.)
- [ ] Case/enclosure exists if the project needs one (keyboards need a case, dev boards do not). The case must actually interface with the internals — a plain rectangle that doesn't secure anything doesn't count
- [ ] .STEP file exists if the project has a 3D CAD model (not required for PCB-only projects)
- [ ] CAD source file exists (.f3d, .FCStd, or public OnShape link). Note: KiCad is PCB design software, not 3D modelling CAD
- [ ] PCB source files exist if applicable (.kicad_pro, .kicad_sch, gerbers, etc). .STEP files are not PCB sources
- [ ] Wiring diagram exists and is clear enough that someone else could follow it
- [ ] Firmware/software source code is present (even if untested)
- [ ] Files are organized into logical folders (not all dumped in root)
- [ ] Assembly plan is documented — how things connect (screws, glue, solder, tape, sewing, etc). Someone else needs to be able to replicate this

## Design integrity

Use your judgment here. Consult the Oracle if you're genuinely unsure, but gather all context first.

- [ ] The design looks real and functional, not just cosmetic
- [ ] PCBs are real circuits with actual components, not empty boards
- [ ] Wiring makes sense electrically — a mess of wires is not OK
- [ ] The case/enclosure actually secures components, not just loosely encloses them
- [ ] The project has a plausible plan for being a real, working thing

**Important:** Check images and CAD files directly. Don't infer from filenames alone. Use GetImage, RenderStepFile, ViewKicadSchematic, and ViewKicadPcb to actually look at things. Don't assume — use web search, Oracle, and visual tools to verify when unsure.

## BOM & parts sourcing

- [ ] BOM has realistic parts with real, working purchase links (where applicable — see note above about when links aren't required)
- [ ] No tools or unrelated items in the BOM (no oscilloscopes, soldering irons, etc)
- [ ] Parts are reasonably priced — no $40 Amazon modules when the same thing is $5 on AliExpress
- [ ] Budget isn't being padded unnecessarily
- [ ] EING (gold plating) is not included unless the project has golden fingers (on-PCB USB-C contacts etc)

## Conditional requirements

Not every project needs everything. Apply judgment:

- PCB-only projects don't need CAD source files or .STEP files — it doesn't make sense
- Projects without a microcontroller don't need firmware
- Generic controller devices (devboards, 3D printer control boards, etc) don't need wiring diagrams or usage examples
- **Check the images before assuming** whether a CAD model or enclosure exists. Many projects may only have a PCB!

## Journal quality

See an example of a good journal: https://github.com/qcoral/hardware-docs/blob/main/site/src/content/docs/shipping/example-journal.md

- [ ] Journal entries exist (minimum 3 expected for most projects)
- [ ] Entries describe actual build progress (not filler, copy-paste, or unrelated content)
- [ ] Entries contain images showing work in progress
- [ ] Time durations are plausible (not all identical, not suspiciously round)
- [ ] Entries span multiple days/sessions (not all written in one sitting)

## JSON check names for this phase

Use these keys in the `checks` object of your JSON output:

`readme_exists`, `readme_description`, `readme_build_instructions`, `readme_motivation`, `readme_3d_screenshot`, `readme_pcb_screenshot`, `readme_wiring_diagram`, `readme_bom_table`, `bom_csv_with_links`, `case_enclosure`, `step_file`, `cad_source`, `pcb_sources`, `wiring_diagram`, `firmware_present`, `files_organized`, `assembly_plan`, `design_integrity`, `bom_sourcing`, `journal_exists`, `journal_progress`, `journal_images`, `journal_plausible_times`, `journal_multiple_sessions`, `no_ai_content`, `original_design`
