//
//  BTSPieViewValues.h
//
//  Copyright (c) 2011 Brian Coyner. All rights reserved.
//

// C++ class that collects and calculates values from the data source.

class BTSPieViewValues {
public:
    typedef CGFloat(^BTSFetchBlock)(NSUInteger index);

    BTSPieViewValues(unsigned int sliceCount, BTSFetchBlock fetchBlock)
    : _sliceCount (sliceCount)
    , _percentages(new double [sliceCount])
    , _values(new double [sliceCount])
    , _angles(new CGFLOAT_TYPE[sliceCount]) {
        double sum = 0.0;
        for (NSUInteger currentIndex = 0; currentIndex < sliceCount; currentIndex++) {
            _values[currentIndex] = fetchBlock(currentIndex);
            sum += _values[currentIndex];
        }

        CGFloat twoPie = (CGFloat) M_PI * 2.0;
        for (int currentIndex = 0; currentIndex < sliceCount; currentIndex++) {
            double percentage = _values[currentIndex] / sum;
            _percentages[currentIndex] = percentage;

            CGFloat angle = (CGFloat) (twoPie * percentage);
            _angles[currentIndex] = angle;
        }
    }

    ~BTSPieViewValues() {
        delete[] _percentages;
        delete[] _values;
        delete[] _angles;
    }

    const double *values() const {
        return _values;
    }

    const double *percentages() const {
        return _percentages;
    }

    const CGFloat *angles() const {
        return _angles;
    }

    unsigned int count() const {
        return _sliceCount;
    }

private:
    unsigned int _sliceCount;
    double *_percentages;
    double *_values;
    CGFloat *_angles;
};
