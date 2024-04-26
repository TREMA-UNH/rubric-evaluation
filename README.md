# Pencils Down! Automatic Rubric-based Evaluation of Retrieve/Generate Systems

-- Online Appendix ---

# TREC  Data Sets used in Experimental Evaluation

- **dl19**: [TREC DL 2019](https://microsoft.github.io/msmarco/TREC-Deep-Learning)  Using 43 queries in the question-form from
the Deep Learning track, harvested from search logs. The sys-
tem’s task is to retrieve passages from a web collection that
answer the query. The official track received 35 systems, met-
rics are NDCG@10, MAP, and MRR.
-  **dl20**: [TREC DL 2020](https://microsoft.github.io/msmarco/TREC-Deep-Learning) Similar setup as the previous Deep Learning
track, but with 54 additional queries and 59 submitted sys-
tems.
- **car**: [TREC CAR Y3](http://trec-car.cs.unh.edu/datareleases/) : Comprising 131 queries and 721 query sub-
topics from the TREC Complex Answer Retrieval track. These
were harvested from titles and section headings from school
text books provided in the TQA dataset [13]. The system’s task
is to retrieve Wikipedia passages to synthesize a per-query re-
sponse that covers all query subtopics. Official track metrics
are MAP, NDCG@20, and R-precision; of 22 systems were
submitted to this track, several have identical rankings. We
use 16 distinguishable systems used by Sander et al.

# Unabridged Results

Below results that were presented in the manuscript in abridged form

* Extended Results for DL20: [dl20-extended-results/](dl20-extended-results/])

* Full DL20 leaderboard with RUBRIC-MRR including systems that generated content via GPT: [results-leaderboard-with-generation-systems/>](results-leaderboard-with-generation-systems/)

* Manual Verification for DL20  query 940547, "When did rock'n'roll begin?": [dl20-manual-verification/](dl20-manual-verification/)


# Workbench Software

All experiments can be reproduced with the [Autograder Workbench](https://github.com/TREMA-UNH/autograding-workbench)  software.



# Data for Reproduction


Please see folder [scripts](scripts) for detailed bash scripts for reproducing results in this paper for each dataset.

We provide data produced by different phases of the RUBRIC approach


Each grade annotation appraoch is denoted as a `prompt_class`. Here the semantics:

* `QuestionSelfRatedUnanswerablePromptWithChoices`:  (question-) RUBRIC 
* `NuggetSelfRatedPrompt`: Nugget RUBRIC
* `Thomas. Sun, Sun\_few, HELM, FagB, FagB\_few`: direct grading prompts


## Preprocessing: Input Data

The data for TREC DL cannot be redistributed under the licensing model.

Input data for CAR is provided in folder <iinput-data/>

## Phase 1: Generated Grading Rubrics

Generated test questions amd nuggets for query-specific rubrics are in folder [phase1-data/](phase1-data/)

## Phase 2:  RUBRIC Grading

Grade annotationsn for  (question) RUBRIC, nugget-RUBRIC, and all direct grading prompts are in folder [phase2-data/](phase2-data/)

Since files are too large for github, we further compress. Please uncompress `xz`, but keep `gz` compression.


## Phase 3: RUBRIC-based Evaluation Metrics

We provide all generated trec_eval compatible "qrels" files in this folder [phase3-qrels/](phase3-qrels/)



## Results

Leaderboard correlation results are found in filder [results-leaderboard-correlation/](results-leaderboard-correlation/)

(nan's indicate that no grade with this minimum grade level is available, example binary grading prompts or Thomas for level  larger than 2)









