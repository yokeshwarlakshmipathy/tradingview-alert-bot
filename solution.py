n = int(input())
arr = list(map(int, input().split()))
initial_sum = sum(arr)

# We need N * x > initial_sum
# So x > initial_sum / N
# The minimum integer x is floor(initial_sum / N) + 1
x = (initial_sum // n) + 1

print(x)
