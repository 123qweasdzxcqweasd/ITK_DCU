#ifndef itk_dcu_arm_aligned_metric_h
#define itk_dcu_arm_aligned_metric_h

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <iomanip>
#include <iostream>
#include <limits>
#include <string>

namespace arm_aligned_metric
{
inline double
MaxAbsoluteError(const float * a, const double * b, std::size_t count)
{
  if (a == nullptr || b == nullptr)
  {
    return std::numeric_limits<double>::infinity();
  }
  double result = 0.0;
  for (std::size_t i = 0; i < count; ++i)
  {
    const double av = static_cast<double>(a[i]);
    const double bv = b[i];
    if (!std::isfinite(av) || !std::isfinite(bv))
    {
      return std::numeric_limits<double>::infinity();
    }
    result = std::max(result, std::abs(av - bv));
  }
  return result;
}

inline void
Report(const std::string & function,
       const std::string & inputSource,
       const std::string & dimensions,
       const std::string & pixelType,
       double              floatMs,
       double              doubleMs,
       double              maxAbs)
{
  const double speedup = floatMs > 0.0 ? doubleMs / floatMs : 0.0;
  std::cout << std::setprecision(12) << "ARM_ALIGNED_METRIC"
            << " function=" << function
            << " input_source=" << inputSource
            << " dimensions=" << dimensions
            << " pixel_type=" << pixelType
            << " float_ms=" << floatMs
            << " double_ms=" << doubleMs
            << " speedup=" << speedup
            << " max_abs=" << maxAbs << '\n';
}
} // namespace arm_aligned_metric

#endif
