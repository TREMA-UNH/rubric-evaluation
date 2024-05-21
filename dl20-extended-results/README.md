Extended Results on TREC DL20
=========================

<!-- 
1. Results of DL20 participating methods on Autograder-Qrels
2. Results of DL20 participating methods on Autograder-Cover (including standard error bars)
3. Results of ChatGPT-based IR generation methods on Autograder-Qrels -->


## Unabridged Quantitative Rresults 

|  | Autograder Qrels | Autograder Cover |  |
| --- | :-- | :-- | :-- |
| DL20 participants | [Results](dl20-qrels.mkd) + leaderboad correlation| [Results](dl20-cover.mkd) with stderr |  |
| ChatGPT-methods | [Results](generation-methods-dl20-qrels.mkd) with stderr + leaderboard rank | [Results](generation-methods-dl20-cover.mkd) + leaderboard rank |  |



We find that with the question-based autograder-qrels we can reproduce the original DL20 leaderboard  nearly exactly ([Spearman rank 0.972, Kendall tau 0.872](dl20-qrels.mkd)), even when using only 10 automatically generated questions per query. The nugget-based approach is also a strong contender.

The [autograde-cover metric](dl20-cover.mkd) is based on how many of nuggets/questions are covered anywhere in the top 20 of the system response (without awarding redundant responses). While we did not expect a high leaderboard correlation, we were positively surprised with a Spearman rank of 0.953 and Kendall tau of 0.811. 

In addition to ranking based methods from DL20 participants, we apply the autograder method to ChatGPT generated IR system responses (both for [autograder-qrels](generation-methods-dl20-qrels.mkd) and [autograder-cover](generation-methods-dl20-cover.mkd)). We find that question-based autograder-cover obtains the most stable results.




