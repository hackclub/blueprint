# Design Review Checklist

This is the primary review phase — checking that the project design is solid before building.

## README.md

- [ ] README.md exists in the repository root
- [ ] Contains a description of what the project is
- [ ] Contains instructions on how to build/use the project
- [ ] Contains motivation — why the author made it (doesn't need its own section, can be woven into other text)
- [ ] Contains a screenshot or render of the full 3D model (if project has a 3D model)
- [ ] Contains a screenshot of the PCB (if project has a PCB)
- [ ] Contains a wiring diagram (if project has wiring that isn't on a PCB and no schematic covers it)
- [ ] Contains a BOM table with component names, quantities, and purchase links where applicable
- [ ] README is reasonably formatted — uses headings, sections, or clear structure. A single wall of text or large unbroken paragraph is not acceptable

## Repository structure

- [ ] BOM file exists in CSV format with purchase links for components that are not custom-made, 3D printed, or through PCBA. Links are not required for: parts from well-known vendors where a part number suffices (LCSC, DigiKey, Mouser), parts already owned, or common/generic materials (screws, wire, popsicle sticks, etc.)
- [ ] Case/enclosure exists if the project needs one (keyboards need a case, dev boards do not). The case must actually interface with the internals — a plain rectangle that doesn't secure anything doesn't count
- [ ] .STEP file exists if the project has a 3D CAD model (not required for PCB-only projects)
- [ ] CAD source file exists (.f3d, .FCStd, or public OnShape link). Note: KiCad is PCB design software, not 3D modelling CAD
- [ ] PCB source files exist if applicable (.kicad_pro, .kicad_sch, gerbers, etc). .STEP files are not PCB sources
- [ ] Wiring diagram exists and is clear enough that someone else could follow it. Not required if a schematic already covers all connections
- [ ] Firmware/software source code is present if the project requires custom code. Dev boards, passive electronics, and projects without microcontrollers don't need firmware. There is no need for a sample/demo firmware for projects like devboards which don't have specific logic.
- [ ] Files are organized into logical folders (not all dumped in root)
- [ ] Assembly plan is documented — how things connect (screws, glue, solder, tape, sewing, etc). For simple projects where the full assembly is clearly visible from photos, renders, or CAD screenshots, a missing assembly plan is a **warn** not a fail. For complex projects with many parts where someone couldn't figure out assembly just by looking at it, this is a **fail**. The question: could someone look at what's provided and replicate the build?

## Design integrity

Use your judgment here. Use ResearchAssistant to look up specs when unsure, and gather all context first.

- [ ] The design looks real and functional, not just cosmetic
- [ ] PCBs are real circuits with actual components, not empty boards
- [ ] Wiring makes sense electrically — a mess of wires is not OK
- [ ] The case/enclosure actually secures components, not just loosely encloses them
- [ ] The project has a plausible plan for being a real, working thing
- [ ] The project is buildable as a whole — components, design files, and instructions fit together into something that can plausibly be assembled and work. Unless the project is very simple, the pieces should coherently come together

**Important:** Check images and CAD files directly. Don't infer from filenames alone. Use GetImage, RenderStepFile, ViewKicadSchematic, and ViewKicadPcb to actually look at things. Don't assume — use ResearchAssistant and visual tools to verify when unsure.

## BOM & parts sourcing

- [ ] BOM has realistic parts with real purchase links (where applicable — see note above about when links aren't required). Broken BOM links are a **warn**, not a fail — links go stale and this alone shouldn't block a project
- [ ] No tools or unrelated items in the BOM (no oscilloscopes, soldering irons, etc)
- [ ] Parts are reasonably priced — no $40 Amazon modules when the same thing is $5 on AliExpress
- [ ] Budget isn't being padded unnecessarily
- [ ] EING (gold plating) is not included unless the project has golden fingers (on-PCB USB-C contacts etc)

## Conditional requirements

Not every project needs everything. Apply judgment:

- PCB-only projects don't need CAD source files or .STEP files — it doesn't make sense
- Projects without a microcontroller don't need firmware. Dev boards and passive electronics projects have no firmware to write
- Projects that need custom application logic (robot cars, weather stations, game controllers, etc.) DO need firmware — a sample blink sketch doesn't satisfy this
- Generic controller devices (devboards, 3D printer control boards, etc) don't need wiring diagrams or usage examples
- A schematic covers wiring — if a project has a proper schematic showing all connections, a separate wiring diagram is redundant. Only require a wiring diagram when there's off-PCB wiring that isn't documented in a schematic
- **Check the images before assuming** whether a CAD model or enclosure exists. Many projects may only have a PCB!

## Journal quality

See an example of a good journal: https://github.com/qcoral/hardware-docs/blob/main/site/src/content/docs/shipping/example-journal.md

- [ ] Journal entries exist (minimum 3 expected for most projects)
- [ ] Entries describe actual build progress (not filler, copy-paste, or unrelated content)
- [ ] Entries contain images showing work in progress. Broken/missing journal images are a **warn**, not a fail — they may be hosting issues rather than missing documentation
- [ ] Time durations are plausible (not all identical, not suspiciously round)
- [ ] Entries span multiple days/sessions (not all written in one sitting)

## JSON check names for this phase

Use these keys in the `checks` object of your JSON output:

`readme_exists`, `readme_description`, `readme_build_instructions`, `readme_motivation`, `readme_3d_screenshot`, `readme_pcb_screenshot`, `readme_wiring_diagram`, `readme_bom_table`, `readme_formatting`, `bom_csv_with_links`, `case_enclosure`, `step_file`, `cad_source`, `pcb_sources`, `wiring_diagram`, `firmware_present`, `files_organized`, `assembly_plan`, `design_integrity`, `project_buildable`, `bom_sourcing`, `journal_exists`, `journal_progress`, `journal_images`, `journal_plausible_times`, `journal_multiple_sessions`, `no_ai_content`, `original_design`
