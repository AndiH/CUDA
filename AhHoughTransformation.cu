#include "AhHoughTransformation.h"

AhHoughTransformation::AhHoughTransformation()
{}

AhHoughTransformation::AhHoughTransformation(thrust::host_vector<double> xValues, thrust::host_vector<double> yValues, double maxAngle, double everyXDegrees)
: fXValues(xValues),
  fYValues(yValues),
  fMaxAngle(maxAngle),
  fEveryXDegrees(everyXDegrees)

{
	DoChangeContainerToTwoTuples();
	DoConformalMapping();
	DoGenerateAngles();
	DoHoughTransform();
}

AhHoughTransformation::~AhHoughTransformation()
{}

void AhHoughTransformation::DoChangeContainerToTwoTuples() {
	//!< change container from vec<x> and vec<y> to vec<tuple<x, y> >
	thrust::copy(
		thrust::make_zip_iterator(
			thrust::make_tuple(
				fXValues.begin(), 
				fYValues.begin()
			)
		), 
		thrust::make_zip_iterator(
			thrust::make_tuple(
				fXValues.end(), 
				fYValues.end()
			)
		), 
		fXYValues.begin()
	);
}

void AhHoughTransformation::DoConformalMapping() {
	//!< conformal mapping
	thrust::transform(
		fXYValues.begin(),
		fXYValues.end(),
		fXYValues.begin(), // in place copy (== output vector = input vector) - maybe not so full of sense? think about it
		my::confMap()
	);
}

void AhHoughTransformation::DoGenerateAngles() {
	//!< Resize angle vector to match the actual size
	fAngles.resize(fMaxAngle/fEveryXDegrees);
	//!< Fill it
	thrust::sequence(
		fAngles.begin(), 
		fAngles.end(), 
		0., 
		fEveryXDegrees
	);
}

void AhHoughTransformation::DoHoughTransform() {
	/** Attention
	* For every (x*,y*) point a hough transform is done!
	* While this hough transform itself is done in parallel, all hough transforms in whole are done serial, one by one after an other.
	* This might be a point of huge improvements
	*/
	for (int iDataPoints = 0; iDataPoints < fXYValues.size(); iDataPoints++) {
		thrust::device_vector<double> d_tempData(fAngles.size()); //!< Temp vector which is being filled and then pushed back to the main return vector. For every angle point theres a data point, so that's the size of it

		thrust::constant_iterator<thrust::tuple<double, double> > currentData(fXYValues[iDataPoints]); //!< create constant iterator for the conf mapped data 2-tuples

		//! following transformation uses the operator of htransf to run over all elements
		//!   elements being a iterator from angles.start to angles.end with each time the constant iterator with the conf mapped 2-tuple
		//!   the result of the calculation is written in to the d_tempData vector
		thrust::transform(
			thrust::make_zip_iterator(
				thrust::make_tuple(
					fAngles.begin(),
					currentData
				)
			),
			thrust::make_zip_iterator(
				thrust::make_tuple(
					fAngles.end(),
					currentData
				)
			),
			d_tempData.begin(),
			my::htransf()
		);

		fTransformedPoints.push_back(d_tempData); //!< push it back to the main data stack vector

	}
}