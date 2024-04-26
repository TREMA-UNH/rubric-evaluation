#!/bin/bash

set -eo pipefail

### External Input
#
# benchmarkY3test.cbor-outlines.cbor: Convert TREC CAR queries mapping query ID to query subtopics and query text
#
# benchmarkY3test-qrels-runs-with-text.jsonl.gz:  Collect passages from system responses (ranking or generated text) for grading
#    These follow the data interchange model, providing the Query ID, paragraph_id, text. 
#    System's rank information can be stored in paragraph_data.rankings[]
#    If available, manual judgments can be stored in paragraph_data.judgment[]


if [ ! -f "data/car/benchmarkY3test.cbor-outlines.cbor" ]; then
    echo "Error: 'benchmarkY3test.cbor-outlines.cbor' does not exist."
    exit 1
fi




### Phase 1: Test bank generation
#
# Generating an initial test bank from a set of test nuggets or exam questions.
# 
# The following files are produced:
#
# car-questions.jsonl.gz: Generated exam questions
#
# car-nuggets.jsonl.gz Generated test nuggets


echo "\n\n\Generate CAR Nuggets"

#python -O -m exam_pp.question_generation -c data/car/benchmarkY3test.cbor-outlines.cbor -o data/car/car-nuggets.jsonl.gz --use-nuggets --description "A new set of generated nuggets for CAR Y3"

echo "\n\n\Generate CAR Questions"

#python -O -m exam_pp.question_generation -c data/car/benchmarkY3test.cbor-outlines.cbor -o data/car/car-questions.jsonl.gz --description "A new set of generated questions for CAR Y3"





#iungraded="benchmarkY3test-qrels-with-text.jsonl.gz"
ungraded="benchmarkY3test-qrels-runs-with-text.jsonl.gz"


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
# The final produced file is questions-explain--questions-rate--nuggets-explain--nuggets-rate--all-benchmarkY3test-qrels-runs-with-text.jsonl.gz



echo "Grading ${ungraded}. Number of queries:"
zcat data/car/$ungraded | wc -l

withrate="nuggets-rate--all-${ungraded}"
withrateextract="nuggets-explain--${withrate}"

# grade nuggets

# python -O -m exam_pp.exam_grading data/car/$ungraded -o data/car/$withrate --model-pipeline text2text --model-name google/flan-t5-large --prompt-class NuggetSelfRatedPrompt --question-path data/car/car-nuggets.jsonl.gz  --question-type question-bank --use-nuggets  

echo -e "\n\n\ Explained CAR Nuggets"

#python -O -m exam_pp.exam_grading data/car/$withrate  -o data/car/$withrateextract --model-pipeline text2text --model-name google/flan-t5-large --prompt-class NuggetExtractionPrompt --question-path data/car/car-nuggets.jsonl.gz  --question-type question-bank --use-nuggets  







# grade questions

echo -e "\n\n\ Rated CAR Questions"
ungraded="$withrateextract"
withrate="questions-rate--${ungraded}"
withrateextract="questions-explain--${withrate}"


# python -O -m exam_pp.exam_grading data/car/$ungraded -o data/car/$withrate --model-pipeline text2text --model-name google/flan-t5-large --prompt-class QuestionSelfRatedUnanswerablePromptWithChoices --question-path data/car/car-questions.jsonl.gz  --question-type question-bank 



echo -e "\n\n\ Explained CAR Questions"

#python -O -m exam_pp.exam_grading data/car/$withrate  -o data/car/$withrateextract --model-pipeline text2text --model-name google/flan-t5-large --prompt-class QuestionCompleteConciseUnanswerablePromptWithChoices --question-path data/car/car-questions.jsonl.gz  --question-type question-bank 



final=$withrateextract
# ****replace back!!!
#
final="FagB-questions-explain--questions-rate--nuggets-explain--nuggets-rate--all-benchmarkY3test-qrels-runs-with-text.jsonl.gz"
#
##
##

# direct grading
##

in=$final
##
#
# ****Add FagB
# 
#
for direct in Sun FagB_few HELM Sun_few Thomas; do
	echo "direct grading $direct"

	out="$direct-$in"
	python -O -m exam_pp.exam_grading data/car/$in  -o data/car/$out --model-pipeline text2text --model-name google/flan-t5-large --prompt-class "$direct" --question-path data/car/car-questions.jsonl.gz  --question-type question-bank 


	in="$out"
	final="$out"
done



echo "Graded: $final"


#### Phase 3: Manual verification and Supervision
# We demonstrate how we support humans conducting a manual supervision of the process
#
# the files produced in this phase are:
# dl-verify-grading.txt : answers to the grading propts selfrated/extraction (grouped by question/nugget)
# car-bad-question.txt : Questions/nuggets frequently covered by non-relevant passages (should be removed from the test bank)
# car-uncovered-passages.txt : Relevant passages not covered by any question/nugget (require the addition of new test nuggets/questions.
#

#python -O -m exam_pp.exam_verification --verify-grading data/car/$final  --question-path data/car/car-questions.jsonl.gz  --question-type question-bank  > data/car/car-verify-grading.txt

#python -O -m exam_pp.exam_verification --uncovered-passages data/car/$final --question-path data/car/car-questions.jsonl.gz  --question-type question-bank --min-judgment 1 --min-rating 4 > data/car/car-uncovered-passages.txt

#python -O -m exam_pp.exam_verification --bad-question data/car/$final  --question-path data/car/car-questions.jsonl.gz  --question-type question-bank --min-judgment 1 --min-rating 4  >  data/car/car-bad-question.txt



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
# Since CAR run files are for query/heading, we need to enable --qrel-query-facets
#
# The files produced in this phase are:
#
# car-autograde-qrels-\$promptclass-minrating-4.solo.qrels:  Exported Qrel file treating passages with self-ratings >=4 
#
# car-autograde-qrels-leaderboard-\$promptclass-minrating-4.solo.tsv:  Leaderboard produced with 
#        trec_eval using the exported Qrel file
#
# car-autograde-cover-leaderboard-\$promptclass-minrating-4.solo.tsv: Leaderboads produced with Autograde Cover treating \
# 	test nuggets/questions as answered when any passage obtains a self-ratings >= 4
#
#

if [ ! -d "data/car/carruns" ]; then
    echo "Error: Directory 'data/car/carruns' does not exist."
    exit 1
fi

# self-ratings
for promptclass in  QuestionSelfRatedUnanswerablePromptWithChoices NuggetSelfRatedPrompt Thomas; do
	echo $promptclass

	for minrating in 3 4 5; do
		#python -O -m exam_pp.exam_evaluation data/car/$final --question-set question-bank --prompt-class $promptclass --min-self-rating $minrating --leaderboard-out data/car/car-autograde-cover-leaderboard-$promptclass-minrating-$minrating.solo.$ungraded.tsv --qrel-query-facets

		# N.B. requires TREC-CAR-Y3 runs to be populated in data/car/carruns
		#python -O -m exam_pp.exam_evaluation data/car/$final --question-set question-bank --prompt-class $promptclass -q data/car/car-autograde-qrels-leaderboard-$promptclass-minrating-$minrating.solo.$ungraded.qrels  --min-self-rating $minrating --qrel-leaderboard-out data/car/car-autograde-qrels-$promptclass-minrating-$minrating.solo.$ungraded.tsv --run-dir data/car/carruns --qrel-query-facets
        
		# Since generative IR systems will not share any passages, we represent them as special run files
		##python -O -m exam_pp.exam_evaluation data/car/$final --question-set question-bank --prompt-class $promptclass -q data/car/car-autograde-qrels-leaderboard-$promptclass-minrating-$minrating.solo.$ungraded.qrels  --min-self-rating $minrating --qrel-leaderboard-out data/car/car-autograde-qrels-$promptclass-minrating-$minrating.solo.$ungraded.gen.tsv --run-dir data/car/cargen-runs --qrel-query-facets
		echo ""
	done
done


# binary 
#
for promptclass in  FagB FagB_few HELM Sun Sun_few; do
	echo $promptclass

	# python -O -m exam_pp.exam_evaluation data/car/$final --question-set question-bank --prompt-class $promptclass --leaderboard-out data/car/car-autograde-cover-leaderboard-$promptclass-.solo.$ungraded.tsv --qrel-query-facets

		# N.B. requires TREC-CAR-Y3 runs to be populated in data/car/carruns
	# python -O -m exam_pp.exam_evaluation data/car/$final --question-set question-bank --prompt-class $promptclass -q data/car/car-autograde-qrels-leaderboard-$promptclass.solo.$ungraded.qrels  --qrel-leaderboard-out data/car/car-autograde-qrels-$promptclass.solo.$ungraded.tsv --run-dir data/car/carruns --qrel-query-facets
        
		## Since generative IR systems will not share any passages, we represent them as special run files
	#python -O -m exam_pp.exam_evaluation data/car/$final --question-set question-bank --prompt-class $promptclass -q data/car/car-autograde-qrels-leaderboard-$promptclass-minrating-$minrating.solo.$ungraded.qrels  --min-self-rating $minrating --qrel-leaderboard-out data/car/car-autograde-qrels-$promptclass-minrating-$minrating.solo.$ungraded.gen.tsv --run-dir data/car/cargen-runs --qrel-query-facets
done



#### Additional Analyses
# When manual judgments or official leaderboards are available, these can be used for additional analyses and manual oversight
#
# To demonstrate the correlation with official leaderboards, requires the construction of a JSON dictionary
# official_car_leaderboard.json:  a JSON dictionary mapping method names to official ranks. (these names must match the run files and method names given in `rankings`. In the case of ties, we suggest to assign all tied systems their average rank
#
# For CAR, where the judgment 1 is a non-relevant grade, the we can use the default option or set `--min-relevant-judgment 1`
#
# Produced outputs `car*.correlation.tsv` are leaderboards with rank correlation information (Spearman's rank correlation and Kendall's tau correlation)
#
#
# When manual relevance judgments are available Cohen's kappa inter-annotator agreement can be computed. 
# Manual judgments will be taken from the entries `paragraph_data.judgents[].relevance`
# 
# The produced output is
# car-autograde-inter-annotator-\$promptclass.tex:  LaTeX tables with graded and binarized inter-annotator statistics with Cohen's kappa agreement. ``Min-anwers'' refers to the number of correct answers obtained above a self-rating threshold by a passage. 
# 


if [ ! -f "data/car/official_car_leaderboard.json" ]; then
    echo "Error: 'data/car/official_car_leaderboard.json' does not exist."
    exit 1
fi




python -O -m exam_pp.exam_leaderboard_analysis data/car/$final  --question-set question-bank --prompt-class  QuestionSelfRatedUnanswerablePromptWithChoices NuggetSelfRatedPrompt Thomas FagB FagB_few HELM Sun Sun_few --min-relevant-judgment 1 --trec-eval-metric ndcg_cut.10 map recip_rank  --use-ratings  --qrel-analysis-out data/car/car-autograde-qrels-leaderboard-analysis-graded.correlation.tsv --run-dir data/car/carruns --official-leaderboard data/car/official_car_leaderboard.json --qrel-query-facets

eval_metric="ndcg_cut.10"

# self-rated prompts
for promptclass in  QuestionSelfRatedUnanswerablePromptWithChoices NuggetSelfRatedPrompt Thomas; do
        echo $promptclass

        for minrating in 3 4 5; do
                # autograde-qrels
                # qrel leaderboard correlation
                # N.B. requires TREC-CAR-Y3 runs to be populated in data/car/carruns
                #python -O -m exam_pp.exam_post_pipeline data/car/$final  --question-set question-bank --prompt-class $promptclass  --min-relevant-judgment 1 --trec-eval-metric $eval_metric  --use-ratings --min-trec-eval-level ${minrating} -q data/car/car-exam-$promptclass.qrel --qrel-leaderboard-out data/car/car-autograde-qrels-leaderboard-$promptclass-$eval_metric-minlevel-$minrating.correlation.tsv --run-dir data/car/carruns --official-leaderboard data/car/official_car_leaderboard.json --qrel-query-facets
        
                # autograde-cover 
                # python -O -m exam_pp.exam_post_pipeline data/car/$final  --question-set question-bank --prompt-class $promptclass  --min-relevant-judgment 1 --use-ratings --min-self-rating ${minrating} --leaderboard-out data/car/car-autograde-cover-leaderboard-$promptclass-minlevel-$minrating.correlation.tsv  --official-leaderboard data/car/official_car_leaderboard.json --qrel-query-facets
                echo ""
        done



        # inter-annotator agreement
        #python -O -m exam_pp.exam_post_pipeline data/car/$final  --question-set question-bank --prompt-class $promptclass  --min-relevant-judgment 1 --use-ratings  --inter-annotator-out data/car/car-autograde-inter-annotator-$promptclass.tex --qrel-query-facets
done



# binary prompts
for promptclass in  FagB FagB_few HELM Sun Sun_few; do

        # python -O -m exam_pp.exam_post_pipeline data/car/$final  --question-set question-bank --prompt-class $promptclass  --min-relevant-judgment 1 --min-trec-eval-level 1 --trec-eval-metric $eval_metric -q data/car/car-exam-$promptclass.qrel --qrel-leaderboard-out data/car/car-autograde-qrels-leaderboard-$promptclass-$eval_metric.correlation.tsv --run-dir data/car/carruns --official-leaderboard data/car/official_car_leaderboard.json --qrel-query-facets
        
        # autograde-cover 
        # python -O -m exam_pp.exam_post_pipeline data/car/$final  --question-set question-bank --prompt-class $promptclass  --min-relevant-judgment 1 --leaderboard-out data/car/car-autograde-cover-leaderboard-$promptclass.correlation.tsv  --official-leaderboard data/car/official_car_leaderboard.json --qrel-query-facets
                echo ""

        # python -O -m exam_pp.exam_post_pipeline data/car/$final  --question-set question-bank --prompt-class $promptclass  --min-relevant-judgment 1 --inter-annotator-out data/car/car-autograde-inter-annotator-$promptclass.tex --qrel-query-facets

done











