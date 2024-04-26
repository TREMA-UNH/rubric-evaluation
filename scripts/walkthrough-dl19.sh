#!/bin/bash

set -eo pipefail

### External Input
#
# dl19-queries.json: Convert queries to a JSON dictionary mapping query ID to query Text
#
# trecDL2019-qrels-runs-with-text.jsonl.gz:  Collect passages from system responses (ranking or generated text) for grading
#    These follow the data interchange model, providing the Query ID, paragraph_id, text. 
#    System's rank information can be stored in paragraph_data.rankings[]
#    If available, manual judgments can be stored in paragraph_data.judgment[]


if [ ! -f "data/dl19/dl19-queries.json" ]; then
    echo "Error: 'dl19-queries.json' does not exist."
    exit 1
fi




### Phase 1: Test bank generation
#
# Generating an initial test bank from a set of test nuggets or exam questions.
# 
# The following files are produced:
#
# dl19-questions.jsonl.gz: Generated exam questions
#
# dl19-nuggets.jsonl.gz Generated test nuggets


echo -e "\n\n\nGenerate DL19 Nuggets"

#python -O -m exam_pp.question_generation -q data/dl19/dl19-queries.json -o data/dl19/dl19-nuggets.jsonl.gz --use-nuggets --test-collection dl19 --description "A new set of generated nuggets for DL19"

echo -e "\n\n\Generate DL19 Questions"

#python -O -m exam_pp.question_generation -q data/dl19/dl19-queries.json -o data/dl19/dl19-questions.jsonl.gz --test-collection dl19 --description "A new set of generated questions for DL19"

echo -e "\n\n\nself-rated DL19 nuggets"


ungraded="trecDL2019-qrels-runs-with-text.jsonl.gz"

if [ ! -f "$ungraded" ]; then
    echo "Error: '$ungraded' does not exist."
    exit 1
fi



### Phase 2: Grading
#
# Passages graded with nuggets and questions using the self-rating prompt
# (for formal grades) and the answer extraction prompt for manual verification.
# Grade information is provided in the field exam_grades.
#
# Grading proceeds in multiple iterations, one per prompts.
# starting with the Collected passages. In each phase, the previous output (-o) will be used as input
#
# While each iteration produces a file, the final output will include data from all previous iterations.
#
# The final produced file is questions-explain--questions-rate--nuggets-explain--nuggets-rate--all-trecDL2019-qrels-runs-with-text.jsonl.gz



echo "Grading ${ungraded}. Number of queries:"
zcat data/dl19/$ungraded | wc -l

withrate="nuggets-rate--all-${ungraded}"
withrateextract="nuggets-explain--${withrate}"

# grade nuggets

#python -O -m exam_pp.exam_grading data/dl19/$ungraded -o data/dl19/$withrate --model-pipeline text2text --model-name google/flan-t5-large --prompt-class NuggetSelfRatedPrompt --question-path data/dl19/dl19-nuggets.jsonl.gz  --question-type question-bank --use-nuggets  

echo -e "\n\n\ Explained DL19 Nuggets"

#python -O -m exam_pp.exam_grading data/dl19/$withrate  -o data/dl19/$withrateextract --model-pipeline text2text --model-name google/flan-t5-large --prompt-class NuggetExtractionPrompt --question-path data/dl19/dl19-nuggets.jsonl.gz  --question-type question-bank --use-nuggets  

# grade questions

echo -e "\n\n\ Rated DL19 Questions"
ungraded="$withrateextract"
withrate="questions-rate--${ungraded}"
withrateextract="questions-explain--${withrate}"


#python -O -m exam_pp.exam_grading data/dl19/$ungraded -o data/dl19/$withrate --model-pipeline text2text --model-name google/flan-t5-large --prompt-class QuestionSelfRatedUnanswerablePromptWithChoices --question-path data/dl19/dl19-questions.jsonl.gz  --question-type question-bank 



echo -e "\n\n\ Explained DL19 Questions"

#python -O -m exam_pp.exam_grading data/dl19/$withrate  -o data/dl19/$withrateextract --model-pipeline text2text --model-name google/flan-t5-large --prompt-class QuestionCompleteConciseUnanswerablePromptWithChoices --question-path data/dl19/dl19-questions.jsonl.gz  --question-type question-bank 

final=$withrateextract

# direct grading
##

in=$withrateextract
for direct in FagB FagB_few HELM Sun Sun_few Thomas; do
	echo "direct grading $direct"

	out="$direct-$in"
	#python -O -m exam_pp.exam_grading data/dl19/$in  -o data/dl19/$out --model-pipeline text2text --model-name google/flan-t5-large --prompt-class "$direct" --question-path data/dl19/dl19-questions.jsonl.gz  --question-type question-bank 


	in="$out"
	final="$out"
done



echo "Graded: $final"


#### Phase 3: Manual verification and Supervision
# We demonstrate how we support humans conducting a manual supervision of the process
#
# the files produced in this phase are:
# dl-verify-grading.txt : answers to the grading propts selfrated/extraction (grouped by question/nugget)
# dl19-bad-question.txt : Questions/nuggets frequently covered by non-relevant passages (should be removed from the test bank)
# dl19-uncovered-passages.txt : Relevant passages not covered by any question/nugget (require the addition of new test nuggets/questions.
#

#python -O -m exam_pp.exam_verification --verify-grading data/dl19/$final  --question-path data/dl19/dl19-questions.jsonl.gz  --question-type question-bank  > data/dl19/dl19-verify-grading.txt

#python -O -m exam_pp.exam_verification --uncovered-passages data/dl19/$final --question-path data/dl19/dl19-questions.jsonl.gz  --question-type question-bank --min-judgment 1 --min-rating 4 > data/dl19/dl19-uncovered-passages.txt

#python -O -m exam_pp.exam_verification --bad-question data/dl19/$final  --question-path data/dl19/dl19-questions.jsonl.gz  --question-type question-bank --min-judgment 1 --min-rating 4  >  data/dl19/dl19-bad-question.txt



#### Phase 4: Evaluation
#
# We demonstrate both the Autograder-qrels  and Autograder-cover evaluation approaches
# Both require to select the grades to be used via --model and --prompt_class
# Here we use --model google/flan-t5-large
# and as --prompt_class either QuestionSelfRatedUnanswerablePromptWithChoices or NuggetSelfRatedPrompt.
#
# Alternatively, for test banks with exam questions that have known correct answers (e.g. TQA for CAR-y3), 
# the prompt class QuestionCompleteConcisePromptWithAnswerKey2 can be used to assess answerability.
#
# The files produced in this phase are:
#
# dl19-autograde-qrels-\$promptclass-minrating-4.solo.qrels:  Exported Qrel file treating passages with self-ratings >=4 
#
# dl19-autograde-qrels-leaderboard-\$promptclass-minrating-4.solo.tsv:  Leaderboard produced with 
#        trec_eval using the exported Qrel file
#
# dl19-autograde-cover-leaderboard-\$promptclass-minrating-4.solo.tsv: Leaderboads produced with Autograde Cover treating \
# 	test nuggets/questions as answered when any passage obtains a self-ratings >= 4
#
#

if [ ! -d "data/dl19/dl19runs" ]; then
    echo "Error: Directory 'data/dl19/dl19runs' does not exist."
    exit 1
fi

# self-ratings
for promptclass in  QuestionSelfRatedUnanswerablePromptWithChoices NuggetSelfRatedPrompt Thomas; do
	echo $promptclass

	for minrating in 3 4 5; do
		#python -O -m exam_pp.exam_evaluation data/dl19/$final --question-set question-bank --prompt-class $promptclass --min-self-rating $minrating --leaderboard-out data/dl19/dl19-autograde-cover-leaderboard-$promptclass-minrating-$minrating.solo.$ungraded.tsv 

		# N.B. requires TREC-DL19 runs to be populated in data/dl19/dl19runs
		#python -O -m exam_pp.exam_evaluation data/dl19/$final --question-set question-bank --prompt-class $promptclass -q data/dl19/dl19-autograde-qrels-leaderboard-$promptclass-minrating-$minrating.solo.$ungraded.qrels  --min-self-rating $minrating --qrel-leaderboard-out data/dl19/dl19-autograde-qrels-$promptclass-minrating-$minrating.solo.$ungraded.tsv --run-dir data/dl19/dl19runs 
        
		# Since generative IR systems will not share any passages, we represent them as special run files
		##python -O -m exam_pp.exam_evaluation data/dl19/$final --question-set question-bank --prompt-class $promptclass -q data/dl19/dl19-autograde-qrels-leaderboard-$promptclass-minrating-$minrating.solo.$ungraded.qrels  --min-self-rating $minrating --qrel-leaderboard-out data/dl19/dl19-autograde-qrels-$promptclass-minrating-$minrating.solo.$ungraded.gen.tsv --run-dir data/dl19/dl19gen-runs 
		echo ""
	done
done


# binary 
#
for promptclass in  FagB FagB_few HELM Sun Sun_few; do
	echo $promptclass

	# python -O -m exam_pp.exam_evaluation data/dl19/$final --question-set question-bank --prompt-class $promptclass --leaderboard-out data/dl19/dl19-autograde-cover-leaderboard-$promptclass-.solo.$ungraded.tsv 

		# N.B. requires TREC-DL19 runs to be populated in data/dl19/dl19runs
	# python -O -m exam_pp.exam_evaluation data/dl19/$final --question-set question-bank --prompt-class $promptclass -q data/dl19/dl19-autograde-qrels-leaderboard-$promptclass.solo.$ungraded.qrels  --qrel-leaderboard-out data/dl19/dl19-autograde-qrels-$promptclass.solo.$ungraded.tsv --run-dir data/dl19/dl19runs 
        
		## Since generative IR systems will not share any passages, we represent them as special run files
	#python -O -m exam_pp.exam_evaluation data/dl19/$final --question-set question-bank --prompt-class $promptclass -q data/dl19/dl19-autograde-qrels-leaderboard-$promptclass-minrating-$minrating.solo.$ungraded.qrels  --min-self-rating $minrating --qrel-leaderboard-out data/dl19/dl19-autograde-qrels-$promptclass-minrating-$minrating.solo.$ungraded.gen.tsv --run-dir data/dl19/dl19gen-runs 
done



#### Additional Analyses
# When manual judgments or official leaderboards are available, these can be used for additional analyses and manual oversight
#
# To demonstrate the correlation with official leaderboards, requires the construction of a JSON dictionary
# official_dl19_leaderboard.json:  a JSON dictionary mapping method names to official ranks. (these names must match the run files and method names given in `rankings`. In the case of ties, we suggest to assign all tied systems their average rank
#
# For DL, where the judgment 1 is a non-relevant grade, the option `--min-relevant-judgment 2` must be used (default is 1)
#
# Produced outputs `dl19*.correlation.tsv` are leaderboards with rank correlation information (Spearman's rank correlation and Kendall's tau correlation)
#
#
# When manual relevance judgments are available Cohen's kappa inter-annotator agreement can be computed. 
# Manual judgments will be taken from the entries `paragraph_data.judgents[].relevance`
# 
# The produced output is
# dl19-autograde-inter-annotator-\$promptclass.tex:  LaTeX tables with graded and binarized inter-annotator statistics with Cohen's kappa agreement. ``Min-anwers'' refers to the number of correct answers obtained above a self-rating threshold by a passage. (For \dl{} –-min-relevant-judgment 2 must be set.)
# 


if [ ! -f "data/dl19/official_dl19_leaderboard.json" ]; then
    echo "Error: 'data/dl19/official_dl19_leaderboard.json' does not exist."
    exit 1
fi




python -O -m exam_pp.exam_leaderboard_analysis data/dl19/$final  --question-set question-bank --prompt-class  QuestionSelfRatedUnanswerablePromptWithChoices NuggetSelfRatedPrompt Thomas FagB FagB_few HELM Sun Sun_few --min-relevant-judgment 2 --trec-eval-metric ndcg_cut.10 map recip_rank  --use-ratings  --qrel-analysis-out data/dl19/dl19-autograde-qrels-leaderboard-analysis-graded.correlation.tsv --run-dir data/dl19/dl19runs --official-leaderboard data/dl19/official_dl19_leaderboard.json 

eval_metric="ndcg_cut.10"

# self-rated prompts
for promptclass in  QuestionSelfRatedUnanswerablePromptWithChoices NuggetSelfRatedPrompt Thomas; do
        echo $promptclass

        for minrating in 3 4 5; do
                # autograde-qrels
                # qrel leaderboard correlation
                # N.B. requires TREC-DL19 runs to be populated in data/dl19/dl19runs
                #python -O -m exam_pp.exam_post_pipeline data/dl19/$final  --question-set question-bank --prompt-class $promptclass  --min-relevant-judgment 2 --trec-eval-metric $eval_metric  --use-ratings --min-trec-eval-level ${minrating} -q data/dl19/dl19-exam-$promptclass.qrel --qrel-leaderboard-out data/dl19/dl19-autograde-qrels-leaderboard-$promptclass-$eval_metric-minlevel-$minrating.correlation.tsv --run-dir data/dl19/dl19runs --official-leaderboard data/dl19/official_dl19_leaderboard.json 
        
                # autograde-cover 
                # python -O -m exam_pp.exam_post_pipeline data/dl19/$final  --question-set question-bank --prompt-class $promptclass  --min-relevant-judgment 2 --use-ratings --min-self-rating ${minrating} --leaderboard-out data/dl19/dl19-autograde-cover-leaderboard-$promptclass-minlevel-$minrating.correlation.tsv  --official-leaderboard data/dl19/official_dl19_leaderboard.json
                echo ""
        done



        # inter-annotator agreement
        #python -O -m exam_pp.exam_post_pipeline data/dl19/$final  --question-set question-bank --prompt-class $promptclass  --min-relevant-judgment 2 --use-ratings  --inter-annotator-out data/dl19/dl19-autograde-inter-annotator-$promptclass.tex
done



# binary prompts
for promptclass in  FagB FagB_few HELM Sun Sun_few; do

        # python -O -m exam_pp.exam_post_pipeline data/dl19/$final  --question-set question-bank --prompt-class $promptclass  --min-relevant-judgment 2 --min-trec-eval-level 1 --trec-eval-metric $eval_metric -q data/dl19/dl19-exam-$promptclass.qrel --qrel-leaderboard-out data/dl19/dl19-autograde-qrels-leaderboard-$promptclass-$eval_metric.correlation.tsv --run-dir data/dl19/dl19runs --official-leaderboard data/dl19/official_dl19_leaderboard.json 
        
        # autograde-cover 
        # python -O -m exam_pp.exam_post_pipeline data/dl19/$final  --question-set question-bank --prompt-class $promptclass  --min-relevant-judgment 2 --leaderboard-out data/dl19/dl19-autograde-cover-leaderboard-$promptclass.correlation.tsv  --official-leaderboard data/dl19/official_dl19_leaderboard.json
                echo ""

        # python -O -m exam_pp.exam_post_pipeline data/dl19/$final  --question-set question-bank --prompt-class $promptclass  --min-relevant-judgment 2 --inter-annotator-out data/dl19/dl19-autograde-inter-annotator-$promptclass.tex

done











