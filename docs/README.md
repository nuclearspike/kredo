# Kredo Documentation

Kredo is an experiment: **how much working product can a handful of AI-assisted
sessions actually produce?** The application was built in about 8.6 hours, and
then audited to find out what had really been made. Every line of the code and
every one of these documents was written by an AI agent under human direction.

Four directories, in the order the work happened:

| | Directory | What it is |
|---|---|---|
| 1 | [**`prd/`**](prd/) | **Planned.** 18 documents specifying the product before any code existed — vision, subsystems, data model, API contracts, actor specs, roadmap. Preserved unedited; historical, not current. |
| 2 | [**`fractalflow/`**](fractalflow/) | **Modelled.** Ten living contracts describing the system's actors, truths, commands, policies, and reveals — kept in sync with the code as a rule of the project. The semantic authority. |
| 3 | [**`storytime/`**](storytime/) | **Audited.** Actor-journey reports: what the product actually delivers to each person who uses it, the features its own data is asking for, and the gaps nobody could see from inside. **Start here if you are browsing.** |
| — | [`kiva_api_compatibility.md`](kiva_api_compatibility.md) | How the Kiva-compatible API surfaces map to the real ones. |

New to this methodology? [`storytime/README.md`](storytime/README.md) explains
LSSD and defines its vocabulary — surface, truth, reveal, ladder, compendium and
the rest — for readers who have never encountered it.

Also at the repository root: [`IMPLEMENTATION_LOG.md`](../IMPLEMENTATION_LOG.md)
(the per-phase build log) and [`README_PLANNING.md`](../README_PLANNING.md) (the
original planning bundle's own README).
