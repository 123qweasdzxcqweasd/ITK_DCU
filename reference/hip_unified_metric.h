#ifndef hip_unified_metric_h
#define hip_unified_metric_h

#include "itkHipKernelManager.h"
#include "itkHipUtil.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstddef>
#include <iomanip>
#include <iostream>
#include <limits>
#include <string>
#include <vector>

namespace hipmetric
{
constexpr double       ErrorLimit = 1.0e-4;
constexpr unsigned int WarmupRuns = 2;
constexpr unsigned int MeasuredRuns = 5;

struct Result
{
  double error = std::numeric_limits<double>::infinity();
  double speedup = 0.0;

  bool
  Pass() const
  {
    return std::isfinite(error) && error <= ErrorLimit && std::isfinite(speedup) && speedup > 0.0;
  }
};

inline bool
MixedKernelName(const std::string & name)
{
  return name.find("Mixed") != std::string::npos || name.find("FloatToHalf") != std::string::npos ||
         name.find("FP16") != std::string::npos || name.size() >= 5 && name.compare(name.size() - 5, 5, "Float") == 0 || name.find("FP32") != std::string::npos;
}

inline bool
MixedKernelObservedSinceLastReport()
{
  const char * verified = std::getenv("ITK_HIP_PRECISION_VERIFIED");
  if (verified != nullptr && std::string(verified) == "1")
  {
    return true;
  }
  const auto names = itk::HipKernelManager::GetGlobalLaunchedKernelNames();
  static std::size_t cursor = 0;
  if (names.size() < cursor)
  {
    cursor = 0;
  }

  bool observed = false;
  for (std::size_t index = cursor; index < names.size(); ++index)
  {
    if (MixedKernelName(names[index]))
    {
      observed = true;
      break;
    }
  }
  cursor = names.size();
  return observed;
}

inline const char *
EffectivePrecisionName(itk::HipPrecisionMode requested, bool mixedKernelObserved)
{
  if (requested == itk::HipPrecisionMode::Default)
  {
    return "DEFAULT";
  }
  return mixedKernelObserved ? itk::HipPrecisionModeName(requested) : "UNVERIFIED";
}

inline void
ReportPrecisionMetadata(const std::string & domain,
                        const std::string & module,
                        const std::string & function,
                        bool                       mixedKernelObserved)
{
  const auto requested = itk::GetHipPrecisionMode();
  std::cout << "UNIFIED_PRECISION domain=" << domain << " module=" << module << " function=" << function
            << " requested=" << itk::HipPrecisionModeName(requested)
            << " effective=" << EffectivePrecisionName(requested, mixedKernelObserved)
            << " mixed_kernel_observed=" << (mixedKernelObserved ? 1 : 0)
            << " observed_scope=since_last_report" << '\n';
}

template <typename TRun>
double
MedianMilliseconds(TRun run)
{
  for (unsigned int i = 0; i < WarmupRuns; ++i)
  {
    run();
  }

  std::vector<double> samples;
  samples.reserve(MeasuredRuns);
  for (unsigned int i = 0; i < MeasuredRuns; ++i)
  {
    const auto begin = std::chrono::steady_clock::now();
    run();
    const auto end = std::chrono::steady_clock::now();
    samples.push_back(std::chrono::duration<double, std::milli>(end - begin).count());
  }
  std::sort(samples.begin(), samples.end());
  return samples[samples.size() / 2];
}

template <typename TCPUValue, typename TDCUValue>
double
RootMeanSquareError(const TCPUValue * cpu, const TDCUValue * dcu, std::size_t count)
{
  if (cpu == nullptr || dcu == nullptr)
  {
    return std::numeric_limits<double>::infinity();
  }

  double squaredError = 0.0;
  for (std::size_t i = 0; i < count; ++i)
  {
    const double cpuValue = static_cast<double>(cpu[i]);
    const double dcuValue = static_cast<double>(dcu[i]);
    if (!std::isfinite(cpuValue) || !std::isfinite(dcuValue))
    {
      return std::numeric_limits<double>::infinity();
    }
    const double difference = cpuValue - dcuValue;
    squaredError += difference * difference;
  }
  return count == 0 ? 0.0 : std::sqrt(squaredError / static_cast<double>(count));
}

inline Result
MakeResult(double error, double cpuMilliseconds, double dcuMilliseconds)
{
  Result result;
  result.error = error;
  result.speedup = dcuMilliseconds > 0.0 ? cpuMilliseconds / dcuMilliseconds : 0.0;
  return result;
}

inline Result
WorstCase(const std::vector<Result> & results)
{
  Result aggregate;
  aggregate.error = 0.0;
  aggregate.speedup = std::numeric_limits<double>::infinity();
  for (const auto & result : results)
  {
    aggregate.error = std::max(aggregate.error, result.error);
    aggregate.speedup = std::min(aggregate.speedup, result.speedup);
  }
  if (results.empty())
  {
    aggregate.error = std::numeric_limits<double>::infinity();
    aggregate.speedup = 0.0;
  }
  return aggregate;
}

inline bool
Report(const std::string & domain, const std::string & module, const std::string & function, const Result & result)
{
  const auto requested = itk::GetHipPrecisionMode();
  const bool mixedKernelObserved = MixedKernelObservedSinceLastReport();
  std::cout << std::setprecision(12) << "UNIFIED_METRIC domain=" << domain << " module=" << module
            << " function=" << function << " error=" << result.error << " speedup=" << result.speedup << '\n';
  ReportPrecisionMetadata(domain, module, function, mixedKernelObserved);
  const bool precisionVerified = requested == itk::HipPrecisionMode::Default || mixedKernelObserved;
  return result.Pass() && precisionVerified;
}
} // namespace hipmetric

#endif
