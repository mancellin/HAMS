!
!  ------------------------------------------------------------------------------------------------------
!                                                               
!    Program HAMS for the diffraction and radiation of waves 
!    by 3D structures.
! 
!             Code Original Author: Yingyi Liu       created on  2012.08.07 
! 
!  License:
! 
!    This routine is part of HAMS.
!
!    HAMS is a free software framework: you can redistribute it and/or modify it 
!    under the terms of the Apache License, Version 2.0 (the "License"); you may 
!    not use this subroutine except in compliance with the License. The software is 
!    distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND.
!
!    You should have received a copy of the Apache License, Version 2.0, along with 
!    HAMS. If not, see <http://www.apache.org/licenses/LICENSE-2.0>.
!
!  Brief introduction:
!
!    HAMS (Hydrodynamics Analysis of Marine Structures) can solve boundary value problems
!    in a three dimensional region using the boundary element method. The problems this code 
!    can handle are of the following form -
!
!    1.  Differential equation inside a region
!
!         Laplace equation
!
!    2.  Boundary conditions
!
!         Use the free-surface Green function to satisfy except body surface condition  
!
!    The program as now written should read a mesh file generated by other softwares,
!    discretized by 3-node triangle or 4-node quadrilateral constant element.
!
!    Bodies that can be applied to: 
!       either floating or submerged.
!
!    Integration rule: 
!       single point scheme.
!
!    Computational efficiency: 
!    In this version, the code has been optimized for maximum computation speed. To further
!    accelerate the computation, you are recommended to use appropriate more threads for the 
!    OpenMp parallel option.
!
!  Refer to the following papers for the theory in detail:
!
!    (1) Yingyi Liu, Hidetsugu Iwashita, Changhong Hu (2015). A calculation method for finite depth
!     free-surface green function. International Journal of Naval Architecture and Ocean Engineering, 
!     7 :375-389. DOI: 10.1515/ijnaoe-2015-0026
!    (2) Yingyi Liu, Changhong Hu, Makoto Sueyoshi, Hidetsugu Iwashita, Masashi Kashiwagi (2016). 
!     Motion response prediction by hybrid panel-stick models for a semi-submersible with bracings. 
!     Journal of Marine Science and Technology, 21:742-757. DOI: 10.1007/s00773-016-0390-1
!    (3) Papers to be continued...
!
!   ######### Version released at October, 2020 ####################

!  ---------------------------------------------------------------------------------------------------------
!  
      Program HAMS
      USE AssbMatx
      USE AssbMatx_irr
      USE CalGreenFunc
      USE ReadPanelMesh
      USE LinearMatrix_mod
      USE HydroStatic
      USE ImplementSubs
      USE CalGreenFunc
      USE PotentWavForce
      USE PrintOutput
      USE Potentials_mod
      USE PressureElevation
      USE FieldOutput_mod
      USE omp_lib

      IMPLICIT NONE  
      
      INTEGER II,KK,MD,MD1,MD2

!======================================================================      
!
    print*
    
    Write(*,'(80A)') ' ------------------------HAMS (Hydrodynamic Analysis of Marine Structures)---------------------'
    print*
    Write(*,'(20x,20A,10x)') '                                     Code Original Author: Yingyi Liu'
    print*
    Write(*,'(80A)') '  HAMS is an open-source software for computing wave diffraction and radiation of 3D structures.'
    print*
    Write(*,'(200A)') ' Please cite the following papers in your publications, reports, etc., when HAMS has been used in your work:'
    print*
    Write(*,'(200A)') '  (1) Yingyi Liu. (2019).'
    Write(*,'(200A)') '      HAMS: A Frequency-Domain Preprocessor for Wave-Structure Interactions—Theory, Development, and Application.'
    Write(*,'(200A)') '      Journal of Marine Science and Engineering, 7(3), 81.'
    print*
    Write(*,'(200A)') '  (2) Yingyi Liu et al. (2018). '
    Write(*,'(200A)') '      A reliable open-source package for performance evaluation of floating renewable energy systems in coastal and offshore regions.'
    Write(*,'(200A)') '      Energy Conversion and Management, 174: 516-536.'
    print*
    Write(*,'(200A)') '  (3) Yingyi Liu et al. (2016).'
    Write(*,'(200A)') '      Motion response prediction by hybrid panel-stick models for a semi-submersible with bracings.'
    Write(*,'(200A)') '      Journal of Marine Science and Technology, 21: 742-757.'
    print*
    Write(*,'(200A)') '  (4) Yingyi Liu et al. (2015).'
    Write(*,'(200A)') '      A calculation method for finite depth free-surface green function.'
    Write(*,'(200A)') '      International Journal of Naval Architecture and Ocean Engineering, 7: 375-389.'
    print*
    Write(*,'(200A)') '  Paper list to be continued...'
    print*
    Write(*,'(80A)') ' -----------------------------------------------------------------------------------------------'
    
    print*
!
!======================================================================        
  
      CALL Initialisation
     
      CALL ReadOpenFiles
 
      CALL OMP_SET_NUM_THREADS(nthread)

      write(*,*) ' Number of machine processors:   ',omp_get_num_procs()
      write(*,*) ' Number of OpenMP threads:       ',nthread      
      write(*,*) ' Maximum number of threads:      ',omp_get_max_threads()
      write(*,*) ' The No. of the current thread:  ',omp_get_num_threads()
      write(*,*) 
  
      DO II=1,3
       READ(2,*)
      ENDDO
         
      IF (IRSP.NE.0) THEN
        DO II=1,3
         READ(5,*)
        ENDDO
      ENDIF
        
      READ(2,*) NELEM, NTND, ISX, ISY

      DO II=1,2
       READ(2,*)
      ENDDO

      IF (IRSP.EQ.0) THEN
        TNTND=NTND
        TNELEM=NELEM
      ELSE
        READ(5,*) INELEM, INTND, ISX, ISY
        TNTND=NTND+INTND
        TNELEM=NELEM+INELEM
        ALLOCATE(iXYZ(INTND,3),iDS(INELEM),iPNSZ(INELEM))
        ALLOCATE(iNCN(INELEM),iNCON(INELEM,4))
        ALLOCATE(iXYZ_P(INELEM,3),iDXYZ_P(INELEM,6))
        DO II=1,2
          READ(5,*)
        ENDDO
      ENDIF

      IF (ISX.EQ.0.AND.ISY.EQ.0) THEN
        ISYS=0
        NSYS=1
      ELSEIF (ISX.EQ.1.AND.ISY.EQ.1) THEN
        print*, ' Warning: at present, ISX and ISY cannot be simultaneously 1.'
        STOP
      ELSE
        ISYS=1
        NSYS=2
      ENDIF
         
      ALLOCATE(XYZ(NTND,3),DS(NELEM),PNSZ(NELEM))
      ALLOCATE(NCN(NELEM),NCON(NELEM,4))
      ALLOCATE(XYZ_P(NELEM,3),DXYZ_P(NELEM,6))
         
      CALL ReadBodyMesh
      IF (IRSP.NE.0) THEN 
        CALL ReadWTPLMesh
      ENDIF
 
       ALLOCATE(AMAT(TNELEM,TNELEM,NSYS),BRMAT(TNELEM,6,NSYS),BDMAT(TNELEM,NSYS),IPIV(NELEM,NSYS))
       ALLOCATE(CGRN(NELEM,NELEM,NSYS,4),RKBN(NELEM,NELEM,NSYS,4))
       ALLOCATE(MXPOT(NELEM,7,NSYS),WVFQ(NPER),EXFC(NPER,NBETA,6),DSPL(NPER,NBETA,6),AMAS(NPER,6,6),BDMP(NPER,6,6))

       IF (IRSP.EQ.1) THEN
        ALLOCATE(DGRN(INELEM,NELEM,NSYS,4),PKBN(INELEM,NELEM,NSYS,4))
        ALLOCATE(CMAT(NELEM,NELEM,NSYS),DRMAT(NELEM,6,NSYS),DDMAT(NELEM,NSYS))
       ENDIF
       
       CALL ReadHydroStatic
      
       CALL CalNormals
      
       write(*,*) ' Number of geometrial symmetries:',ISYS
       write(*,*) ' Number of panels on the hull:   ',NELEM
       write(*,*) ' Number of panels on waterplanes:',INELEM
       PRINT*
       write(*,*) ' Radiation-diffraction computation starts...'

       !PRINT*
       !PRINT*,' The number of threads used for OpenMP is:',NTHREAD

! ================================================================

 !      IF (SYBO.EQ.1) THEN
 !      
 !      BETA=0.D0
 !      TP=-1.D0
 !      W1=1.E-20
 !      WK=1.E-20
 !      V=1.E-20
 !      WL=-1.D0
 !      
 !      IF (IRSP.EQ.0) THEN
 !       CALL CALGREEN
 !       CALL ASSB_LEFT(AMAT,INDX,NELEM,NSYS)
 !       CALL ASSB_RBC(BRMAT,NELEM,NSYS)
 !       CALL ASSB_DBC(BDMAT,NELEM,NSYS)
 !       CALL RADIATION_SOLVER(AMAT,BRMAT,INDX,MXPOT,NELEM,NSYS)
 !       CALL DIFFRACTION_SOLVER(AMAT,BDMAT,INDX,MXPOT,NELEM,NSYS)
 !      ELSEIF (IRSP.EQ.1) THEN
 !       CALL CALGREEN_IRR
 !       CALL ASSB_LEFT_IRR(AMAT,CMAT,INDX,NELEM,TNELEM,NSYS)
 !       CALL ASSB_RBC_IRR(BRMAT,DRMAT,AMAT,NELEM,TNELEM,NSYS)
 !       CALL ASSB_DBC_IRR(BDMAT,DDMAT,AMAT,NELEM,TNELEM,NSYS)
 !       CALL RADIATION_SOLVER_IRR(CMAT,DRMAT,INDX,MXPOT,NELEM,NSYS)
 !       CALL DIFFRACTION_SOLVER_IRR(CMAT,DDMAT,INDX,MXPOT,NELEM,NSYS)
 !      ENDIF
 !
 !      CALL RFORCE(WK,W1,TP,AMAS0(1,:,:),BDMP0(1,:,:))
 !      CALL EFORCE(WK,W1,TP,BETA,AMP,EXFC0(1,:))
 !!      CALL SolveMotion(WK,W1,TP,WL,AMP,AMAS0(1,:,:),BDMP0(1,:,:),VDMP,EXFC0(1,:),DSPL0(1,:))
 !
 !      TP=0.D0
 !      W1=-1.D0
 !      WK=-1.D0
 !      V=-1.D0
 !      WL=0.D0
 !      
 !      IF (IRSP.EQ.0) THEN
 !       CALL CALGREEN
 !       CALL ASSB_LEFT(AMAT,INDX,NELEM,NSYS)
 !       CALL ASSB_RBC(BRMAT,NELEM,NSYS)
 !       CALL ASSB_DBC(BDMAT,NELEM,NSYS)
 !       CALL RADIATION_SOLVER(AMAT,BRMAT,INDX,MXPOT,NELEM,NSYS)
 !       CALL DIFFRACTION_SOLVER(AMAT,BDMAT,INDX,MXPOT,NELEM,NSYS)
 !      ELSEIF (IRSP.EQ.1) THEN
 !       CALL CALGREEN_IRR
 !       CALL ASSB_LEFT_IRR(AMAT,CMAT,INDX,NELEM,TNELEM,NSYS)
 !       CALL ASSB_RBC_IRR(BRMAT,DRMAT,AMAT,NELEM,TNELEM,NSYS)
 !       CALL ASSB_DBC_IRR(BDMAT,DDMAT,AMAT,NELEM,TNELEM,NSYS)
 !       CALL RADIATION_SOLVER_IRR(CMAT,DRMAT,INDX,MXPOT,NELEM,NSYS)
 !       CALL DIFFRACTION_SOLVER_IRR(CMAT,DDMAT,INDX,MXPOT,NELEM,NSYS)
 !      ENDIF
 !
 !      CALL RFORCE(WK,W1,TP,AMAS0(2,:,:),BDMP0(2,:,:))
 !      CALL EFORCE(WK,W1,TP,BETA,AMP,EXFC0(2,:))
 !      CALL SolveMotion(WK,W1,TP,WL,AMP,AMAS0(2,:,:),BDMP0(2,:,:),VDMP,EXFC0(2,:),DSPL0(2,:))
 !       
 !      ENDIF
           
! ================================================================
!
       
       DO MD=1,6
         CALL PrintHeading(190+MD,NBETA,REFL,'Excitation',MD,MD,H,XW,XR,WVHD)
         CALL PrintHeading(200+MD,NBETA,REFL,'Motion',MD,MD,H,XW,XR,WVHD)
       ENDDO
       
        DO MD1=1,6
        DO MD2=1,6
         CALL PrintHeading(70+10*(MD1-1)+MD2,NBETA,REFL,'AddedMass',MD1,MD2,H,XW,XR,WVHD)
         CALL PrintHeading(130+10*(MD1-1)+MD2,NBETA,REFL,'WaveDamping',MD1,MD2,H,XW,XR,WVHD)
        ENDDO
        ENDDO
       
       DO KK=1,NPER
 
         CALL CalWaveProperts(KK)       

         IF (INFT.EQ.1.or.INFT.EQ.2) THEN
          WRITE(6,1010) INFR
         ELSEIF (INFT.EQ.3) THEN
          WRITE(6,1030) INFR
         ELSEIF (INFT.EQ.4) THEN
          WRITE(6,1040) INFR
         ELSEIF (INFT.EQ.5) THEN
          WRITE(6,1050) INFR
         ENDIF
             
         IF (IRSP.EQ.0) THEN
          CALL CALGREEN
          CALL ASSB_LEFT(AMAT,IPIV,NELEM,NSYS)
          CALL ASSB_RBC(BRMAT,NELEM,NSYS)
          CALL RADIATION_SOLVER(AMAT,BRMAT,IPIV,MXPOT,NELEM,NSYS)
         ELSEIF (IRSP.EQ.1) THEN
          CALL CALGREEN_IRR
          CALL ASSB_LEFT_IRR(AMAT,CMAT,IPIV,NELEM,TNELEM,NSYS)
          CALL ASSB_RBC_IRR(BRMAT,DRMAT,AMAT,NELEM,TNELEM,NSYS)
          CALL RADIATION_SOLVER_IRR(CMAT,DRMAT,IPIV,MXPOT,NELEM,NSYS)
         ENDIF
 
         CALL RFORCE(WK,W1,TP,AMAS(KK,:,:),BDMP(KK,:,:))
         CALL OutputPressureElevation_Radiation(64)
         
        DO II=1,NBETA

         BETA=WVHD(II)*PI/180.0D0
         WRITE(6,3000) WVHD(II)
         
         IF (IRSP.EQ.0) THEN
          CALL ASSB_DBC(BDMAT,NELEM,NSYS)
          CALL DIFFRACTION_SOLVER(AMAT,BDMAT,IPIV,MXPOT,NELEM,NSYS)
         ELSEIF (IRSP.EQ.1) THEN
          CALL ASSB_DBC_IRR(BDMAT,DDMAT,AMAT,NELEM,TNELEM,NSYS)
          CALL DIFFRACTION_SOLVER_IRR(CMAT,DDMAT,IPIV,MXPOT,NELEM,NSYS)
         ENDIF
 
         CALL EFORCE(WK,W1,TP,BETA,AMP,EXFC(KK,II,:))
         CALL SolveMotion(W1,TP,OUFR,BETA,AMP,AMAS(KK,:,:),BDMP(KK,:,:),VDMP,EXFC(KK,II,:),DSPL(KK,II,:))
         CALL OutputPressureElevation_Diffraction(64)
         
        ENDDO
        
       ENDDO

       DO KK=1,NPER

        DO MD1=1,6
        DO MD2=1,6
         CALL PrintBody_RealVal(70+10*(MD1-1)+MD2,WVFQ(KK),NBETA,'AddedMass',AMAS(KK,MD1,MD2))
         CALL PrintBody_RealVal(130+10*(MD1-1)+MD2,WVFQ(KK),NBETA,'WaveDamping',BDMP(KK,MD1,MD2))
        ENDDO
        ENDDO
        
         DO MD=1,6
          CALL PrintBody_CmplxVal( 190+MD,WVFQ(KK),NBETA,'Excitation',EXFC(KK,:,MD))
          CALL PrintBody_CmplxVal(200+MD,WVFQ(KK),NBETA,'Motion',DSPL(KK,:,MD))
         ENDDO

       ENDDO
! ================================================================

        DO MD=1,6
         CALL PrintEnd(190+MD)
         CALL PrintEnd(200+MD)
        ENDDO
        
        DO MD1=1,6
        DO MD2=1,6
         CALL PrintEnd(70+10*(MD1-1)+MD2)
         CALL PrintEnd(130+10*(MD1-1)+MD2)
        ENDDO
        ENDDO
       
       DEALLOCATE(XYZ,DS,NCN,NCON,XYZ_P,DXYZ_P)
       DEALLOCATE(AMAT,BRMAT,BDMAT,CGRN,RKBN)
       DEALLOCATE(MXPOT,WVHD,EXFC,DSPL,AMAS,BDMP)
     
       IF (IRSP.EQ.1) THEN
        DEALLOCATE(IXYZ,IDS,INCN,INCON,IXYZ_P,IDXYZ_P)
        DEALLOCATE(CMAT,DRMAT,DDMAT,DGRN,PKBN)
       ENDIF

       write(*,*) 
       write(*,*) ' Congratulations! Your computation completes successfully.'
       write(*,*)

!====================================================================================
1600   FORMAT(//, ' Total CPU Time of computation was',F12.3, '  seconds')
1700   FORMAT(//, ' Elapsed Time in computation was',F12.3, '  seconds')
1010   FORMAT(/,10x,'Wave Number =',F9.3,' 1/m')
1030   FORMAT(/,10x,'Wave Frequency =',F9.3,' rad/s')
1040   FORMAT(/,10x,'Wave Period =',F9.3,'  s')
1050   FORMAT(/,10x,'Wave Length =',F9.3,' m')
3000   FORMAT(12x,'Wave Heading =',F9.3,' Degree')
       
      END Program HAMS
